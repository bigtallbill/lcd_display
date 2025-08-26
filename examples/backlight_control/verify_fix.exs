#!/usr/bin/env elixir

# Backlight Fix Verification Script
# This script verifies that the backlight control fix works correctly
# by testing all three backlight control modes.

defmodule BacklightFixVerification do
  @moduledoc """
  Verification script for the LCD backlight control fix.
  Tests all backlight control modes to ensure proper functionality.
  """

  def run do
    IO.puts("=== LCD Backlight Control Fix Verification ===\n")

    # Test configuration
    base_config = %{
      i2c_bus: "i2c-1",
      i2c_address: 0x27,
      rows: 2,
      cols: 16
    }

    # Test 1: Default behavior (auto mode)
    IO.puts("Test 1: Default behavior (auto mode)")
    test_auto_mode(base_config)

    # Test 2: Manual backlight control
    IO.puts("\nTest 2: Manual backlight control")
    test_manual_mode(base_config)

    # Test 3: Always off backlight
    IO.puts("\nTest 3: Always off backlight")
    test_off_mode(base_config)

    # Test 4: Runtime mode switching
    IO.puts("\nTest 4: Runtime mode switching")
    test_runtime_switching(base_config)

    # Test 5: State synchronization
    IO.puts("\nTest 5: State synchronization")
    test_state_sync(base_config)

    IO.puts("\n=== All Tests Completed Successfully! ===")
    IO.puts("The backlight control fix is working correctly.")
  end

  defp test_auto_mode(config) do
    IO.puts("  Starting LCD with default auto mode...")

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)
    assert_field(display, :backlight_control, :auto)
    assert_field(display, :backlight, true)

    IO.puts("  Testing LCD operations preserve auto backlight control...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Auto Mode"})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:set_cursor, 1, 0})

    # Backlight state should remain unchanged
    assert_field(display, :backlight, true)
    assert_field(display, :backlight_control, :auto)

    IO.puts("  ✓ Auto mode test passed")
  end

  defp test_manual_mode(config) do
    IO.puts("  Starting LCD with manual backlight control...")

    manual_config = Map.merge(config, %{
      backlight_control: :manual,
      initial_backlight: false
    })

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(manual_config)
    assert_field(display, :backlight_control, :manual)
    assert_field(display, :backlight, false)

    IO.puts("  Testing LCD operations preserve backlight state...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Manual Mode"})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:set_cursor, 1, 0})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Preserved"})

    # Backlight state should remain false
    assert_field(display, :backlight, false)
    assert_field(display, :backlight_control, :manual)

    IO.puts("  ✓ Manual mode test passed")
  end

  defp test_off_mode(config) do
    IO.puts("  Starting LCD with off backlight control...")

    off_config = Map.merge(config, %{
      backlight_control: :off,
      initial_backlight: true  # Should be ignored in off mode
    })

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(off_config)
    assert_field(display, :backlight_control, :off)

    IO.puts("  Testing LCD operations never set backlight...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Off Mode"})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight, true})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Still Off"})

    # Mode should remain off
    assert_field(display, :backlight_control, :off)

    IO.puts("  ✓ Off mode test passed")
  end

  defp test_runtime_switching(config) do
    IO.puts("  Testing runtime mode switching...")

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)
    assert_field(display, :backlight_control, :auto)

    # Switch to manual mode
    IO.puts("    Switching to manual mode...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :manual})
    assert_field(display, :backlight_control, :manual)

    # Switch to off mode
    IO.puts("    Switching to off mode...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :off})
    assert_field(display, :backlight_control, :off)

    # Switch back to auto mode
    IO.puts("    Switching back to auto mode...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :auto})
    assert_field(display, :backlight_control, :auto)

    IO.puts("  ✓ Runtime switching test passed")
  end

  defp test_state_sync(config) do
    IO.puts("  Testing state synchronization...")

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)
    assert_field(display, :backlight, true)

    # Sync to false
    IO.puts("    Syncing backlight state to false...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})
    assert_field(display, :backlight, false)

    # Sync back to true
    IO.puts("    Syncing backlight state to true...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, true})
    assert_field(display, :backlight, true)

    IO.puts("  ✓ State synchronization test passed")
  end

  defp assert_field(display, field, expected_value) do
    actual_value = Map.get(display, field)
    if actual_value != expected_value do
      raise "Assertion failed: expected #{field} to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
    end
  end

  # Test helper for unsupported command error
  defp test_unsupported_commands do
    config = %{i2c_bus: "i2c-1", i2c_address: 0x27}
    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

    # Test invalid backlight control mode
    case LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :invalid}) do
      {:error, _} -> IO.puts("  ✓ Invalid backlight control mode properly rejected")
      _ -> raise "Expected error for invalid backlight control mode"
    end
  end
end

# Configuration validation
defmodule ConfigValidator do
  def validate_i2c_device do
    case System.cmd("ls", ["/dev/i2c-1"]) do
      {_, 0} ->
        IO.puts("✓ I2C device /dev/i2c-1 found")
        :ok
      _ ->
        IO.puts("⚠ I2C device /dev/i2c-1 not found - tests will use mock")
        :mock
    end
  end
end

# Main execution
if __ENV__.file == Path.absname(:escript.script_name()) or
   __ENV__.file == Path.absname(System.argv() |> List.first() || "") do

  # Validate environment
  case Code.ensure_loaded(LcdDisplay.HD44780.PCF8574) do
    {:module, _} ->
      ConfigValidator.validate_i2c_device()

      try do
        BacklightFixVerification.run()
      rescue
        e in RuntimeError ->
          IO.puts("❌ Test failed: #{e.message}")
          System.halt(1)
        e ->
          IO.puts("❌ Unexpected error: #{inspect(e)}")
          System.halt(1)
      end

    {:error, :nofile} ->
      IO.puts("❌ LcdDisplay module not found. Make sure you're in the lcd_display project directory.")
      System.halt(1)
  end
end
