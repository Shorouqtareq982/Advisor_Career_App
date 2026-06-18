import asyncio
import logging
import time
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable, Dict, Optional

logger = logging.getLogger(__name__)


@dataclass
class ProviderState:
    disabled: bool = False
    failures: int = 0
    reason: Optional[str] = None
    disabled_at: Optional[float] = None


@dataclass
class GenerationRuntime:
    """
    Runtime state for ONE plan generation request.

    Responsibilities:
    - Limit parallel requests.
    - Stop retrying failed providers during the same generation.
    - Return fallback immediately when provider is disabled.
    """

    max_llm_parallel: int = 4
    max_resource_parallel: int = 4

    llm_sem: asyncio.Semaphore = field(init=False)
    resource_sem: asyncio.Semaphore = field(init=False)
    providers: Dict[str, ProviderState] = field(default_factory=dict)

    def __post_init__(self):
        self.llm_sem = asyncio.Semaphore(self.max_llm_parallel)
        self.resource_sem = asyncio.Semaphore(self.max_resource_parallel)

    def is_enabled(self, provider: str) -> bool:
        state = self.providers.get(provider)
        return not state or not state.disabled

    def disable(self, provider: str, reason: str):
        state = self.providers.setdefault(provider, ProviderState())
        state.disabled = True
        state.failures += 1
        state.reason = reason
        state.disabled_at = time.time()

        logger.warning(
            "[GENERATION_RUNTIME] provider disabled | provider=%s | reason=%s",
            provider,
            reason,
        )

    def snapshot(self) -> Dict[str, Any]:
        return {
            provider: {
                "disabled": state.disabled,
                "failures": state.failures,
                "reason": state.reason,
                "disabled_at": state.disabled_at,
            }
            for provider, state in self.providers.items()
        }

    async def run_limited(
        self,
        *,
        semaphore: asyncio.Semaphore,
        provider: str,
        coro_factory: Callable[[], Awaitable[Any]],
        fallback_factory: Callable[[], Any],
        disable_on_error: bool = True,
    ) -> Any:
        """
        Runs provider call with concurrency limit.
        If provider already failed before, skips call and returns fallback.
        """

        if not self.is_enabled(provider):
            logger.info(
                "[GENERATION_RUNTIME] skipping disabled provider | provider=%s",
                provider,
            )
            return fallback_factory()

        async with semaphore:
            if not self.is_enabled(provider):
                return fallback_factory()

            try:
                return await coro_factory()

            except Exception as e:
                reason = f"{type(e).__name__}: {e}"

                if disable_on_error:
                    self.disable(provider, reason)

                return fallback_factory()