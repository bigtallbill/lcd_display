# Exclude integration tests by default since they require special setup
# Run with: mix test --include integration
ExUnit.start(exclude: [:integration])
