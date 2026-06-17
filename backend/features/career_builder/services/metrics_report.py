import matplotlib.pyplot as plt
import logging

logger = logging.getLogger(__name__)

def generate_metrics_report(throughput_data, concurrency_data):
    """
    Generate a report visualizing throughput and concurrency metrics.

    :param throughput_data: List of throughput values over time.
    :param concurrency_data: List of concurrency values over time.
    """
    try:
        # Create a figure with two subplots
        fig, axes = plt.subplots(2, 1, figsize=(10, 8))

        # Plot throughput data
        axes[0].plot(throughput_data, label="Throughput (plans/sec)", color="blue")
        axes[0].set_title("Throughput Over Time")
        axes[0].set_xlabel("Time (seconds)")
        axes[0].set_ylabel("Throughput")
        axes[0].legend()
        axes[0].grid(True)

        # Plot concurrency data
        axes[1].plot(concurrency_data, label="Active Concurrent Tasks", color="green")
        axes[1].set_title("Concurrency Over Time")
        axes[1].set_xlabel("Time (seconds)")
        axes[1].set_ylabel("Concurrency")
        axes[1].legend()
        axes[1].grid(True)

        # Adjust layout and save the report
        plt.tight_layout()
        plt.savefig("metrics_report.png")
        logger.info("Metrics report saved as 'metrics_report.png'")

    except Exception as e:
        logger.error(f"Failed to generate metrics report: {e}")

# Example usage (replace with actual data collection in production)
if __name__ == "__main__":
    example_throughput = [5, 10, 15, 20, 25, 30]  # Example throughput data
    example_concurrency = [1, 2, 3, 4, 5, 6]      # Example concurrency data
    generate_metrics_report(example_throughput, example_concurrency)