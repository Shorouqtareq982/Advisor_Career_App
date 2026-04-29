from __future__ import annotations

from typing import Any, Dict, List, Optional

from shared.providers.supabase import supabase_client


class PortfolioRepository:
	def __init__(self):
		self.client = supabase_client.get_client()

	async def create_portfolio(self, payload: Dict[str, Any]) -> Dict[str, Any]:
		response = self.client.table("portfolios").insert(payload).execute()
		return response.data[0]

	async def update_portfolio(
		self,
		portfolio_id: str,
		payload: Dict[str, Any],
	) -> Dict[str, Any]:
		response = (
			self.client
			.table("portfolios")
			.update(payload)
			.eq("id", portfolio_id)
			.execute()
		)
		return response.data[0]

	async def get_portfolio(self, portfolio_id: str) -> Optional[Dict[str, Any]]:
		response = (
			self.client
			.table("portfolios")
			.select("*")
			.eq("id", portfolio_id)
			.single()
			.execute()
		)

		if not response.data:
			return None

		return response.data

	async def get_user_portfolios(self, user_id: str) -> List[Dict[str, Any]]:
		response = (
			self.client
			.table("portfolios")
			.select(
				"id, title, template_index, is_published, "
				"public_slug, created_at, updated_at"
			)
			.eq("user_id", user_id)
			.order("updated_at", desc=True)
			.execute()
		)

		return response.data

	async def delete_portfolio(self, portfolio_id: str) -> bool:
		(
			self.client
			.table("portfolios")
			.delete()
			.eq("id", portfolio_id)
			.execute()
		)

		return True

	async def publish_portfolio(self, portfolio_id: str, slug: str) -> Dict[str, Any]:
		(
			self.client
			.table("portfolios")
			.update({
				"is_published": True,
				"public_slug": slug,
			})
			.eq("id", portfolio_id)
			.execute()
		)

		return {
			"success": True,
			"slug": slug,
		}

	async def unpublish_portfolio(self, portfolio_id: str) -> bool:
		(
			self.client
			.table("portfolios")
			.update({
				"is_published": False,
			})
			.eq("id", portfolio_id)
			.execute()
		)

		return True

	async def get_last_saved_portfolio_data(self, user_id: str) -> Optional[Dict[str, Any]]:
		print("Fetching last saved portfolio data for user:", user_id)
		response = (
			self.client
			.table("portfolios")
			.select("data")
			.eq("user_id", user_id)
			.order("updated_at", desc=True)
			.limit(1)
			.maybe_single()
			.execute()
		)
		if not response.data:
			return None
		return response.data

	async def get_all_published_portfolios(self) -> List[Dict[str, Any]]:
		response = (
			self.client
			.table("portfolios")
			.select("*")
			.eq("is_published", True)
			.order("updated_at", desc=True)
			.execute()
		)

		return response.data

	async def get_published_portfolio_by_slug(self, slug: str) -> Optional[Dict[str, Any]]:
		response = (
			self.client
			.table("portfolios")
			.select("*")
			.eq("public_slug", slug)
			.eq("is_published", True)
			.single()
			.execute()
		)

		if not response.data:
			return None

		return response.data


portfolio_repo = PortfolioRepository()