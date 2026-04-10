run_integration? = System.get_env("RUN_INTEGRATION_TESTS") == "true"

ExUnit.start(exclude: if(run_integration?, do: [], else: [:integration]))
