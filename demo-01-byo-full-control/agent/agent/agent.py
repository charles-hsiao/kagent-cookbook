import os
from google.adk.agents import Agent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig


def roll_die(num_sides: int) -> dict:
    """Roll a die with the given number of sides."""
    import random
    result = random.randint(1, num_sides)
    return {"result": result, "sides": num_sides}


def check_prime(number: int) -> dict:
    """Check if a number is prime."""
    if number < 2:
        return {"number": number, "is_prime": False}
    for i in range(2, int(number**0.5) + 1):
        if number % i == 0:
            return {"number": number, "is_prime": False}
    return {"number": number, "is_prime": True}


root_agent = Agent(
    name="custom_adk_agent",
    model=os.environ.get("AGENT_MODEL", "gemini-2.5-flash"),
    instruction="""You are a helpful assistant with advanced planning capabilities.
You can roll dice and check prime numbers. Use your reasoning to solve multi-step problems.""",
    # BuiltInPlanner: NOT available in kagent Declarative agents.
    # With BYO, you have full ADK control.
    planner=BuiltInPlanner(
        thinking_config=ThinkingConfig(
            thinking_budget=1024,
            include_thoughts=False,
        )
    ),
    tools=[roll_die, check_prime],
)
