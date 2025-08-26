#!/usr/bin/env elixir

# Manual Backlight Control Demo
# This example demonstrates how to use the new backlight control features
# to prevent LCD operations from interfering with external backlight control.

defmodule BacklightDemo do
  @moduledoc """
  Demonstrates manual backlight control with the PCF8574 driver.
  """

  # PCF8574 I2C address and backlight bit
  @i2c_address 0x27
  @backlight_bit 0x08

  def run do
    IO.puts("=== LCD Backlight Control Demo ===\n")

    # Configuration with manual backlight control
    config = %{
      i2c_bus: "i2c-1",
      i2c_address: @i2c_address,
      rows: 2,
      cols: 16,
      backlight_control: :manual,    # Prevent automatic backlight management
      initial_backlight: false       # Start with backlight off
    }

    IO.puts("1. Starting LCD with manual backlight control...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

    # Test that LCD operations don't turn on backlight
    IO.puts("2. Clearing display (backlight should stay off)...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)

    IO.puts("3. Printing text (backlight should stay off)...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Backlight Test"})

    IO.puts("4. Setting cursor (backlight should stay off)...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:set_cursor, 1, 0})

    IO.puts("5. Printing more text (backlight should stay off)...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Manual Control"})

    # Demonstrate external backlight control
    IO.puts("\n6. Turning backlight ON via direct I2C...")
    set_backlight_direct(true)

    # Sync the library's internal state
    IO.puts("7. Syncing library state with external control...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, true})

    IO.puts("8. More LCD operations (backlight should stay on)...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:set_cursor, 0, 0})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Still ON!"})

    IO.puts("\n9. Turning backlight OFF via direct I2C...")
    set_backlight_direct(false)

    # Sync the library's internal state
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})

    IO.puts("10. Final LCD operation (backlight should stay off)...")
    {:ok, _display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, " OFF"})

    IO.puts("\n=== Demo complete! ===")
    IO.puts("The backlight was controlled externally without interference from LCD operations.")

    # Demonstrate different backlight control modes
    demonstrate_modes()
  end

  defp demonstrate_modes do
    IO.puts("\n=== Backlight Control Modes Demo ===\n")

    config = %{
      i2c_bus: "i2c-1",
      i2c_address: @i2c_address,
      rows: 2,
      cols: 16,
      backlight_control: :auto  # Start in auto mode
    }

    {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

    IO.puts("Mode: :auto (default behavior)")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Auto mode"})
    Process.sleep(2000)

    IO.puts("Switching to :manual mode...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :manual})
    set_backlight_direct(false)
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, " Manual"})
    Process.sleep(2000)

    IO.puts("Switching to :off mode...")
    {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :off})
    {:ok, _display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, " Off"})

    IO.puts("Mode demo complete!")
  end

  defp set_backlight_direct(on_off) do
    # Direct I2C control as mentioned in the issue
    {:ok, i2c_ref} = Circuits.I2C.open("i2c-1")

    data = if on_off, do: @backlight_bit, else: 0x00
    :ok = Circuits.I2C.write(i2c_ref, @i2c_address, [data])

    Circuits.I2C.close(i2c_ref)
  end
end

# Run the demo if this script is executed directly
if __ENV__.file == Path.absname(:escript.script_name()) or
   __ENV__.file == Path.absname(System.argv() |> List.first() || "") do

  # Check if required dependencies are available
  case Code.ensure_loaded(Circuits.I2C) do
    {:module, _} ->
      try do
        BacklightDemo.run()
      rescue
        e ->
          IO.puts("Error running demo: #{inspect(e)}")
          IO.puts("Make sure your I2C device is connected and accessible.")
      end

    {:error, :nofile} ->
      IO.puts("This demo requires the circuits_i2c dependency.")
      IO.puts("Add {:circuits_i2c, \"~> 1.0\"} to your mix.exs deps.")
  end
end
