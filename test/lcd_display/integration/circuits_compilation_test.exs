defmodule LcdDisplay.Integration.CircuitsCompilationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  # Override test config to use real circuits libraries for integration tests
  setup do
    # Save original config
    original_gpio = Application.get_env(:lcd_display, :gpio_module)
    original_i2c = Application.get_env(:lcd_display, :i2c_module)
    original_spi = Application.get_env(:lcd_display, :spi_module)

    # Set to use real circuits libraries
    Application.put_env(:lcd_display, :gpio_module, Circuits.GPIO)
    Application.put_env(:lcd_display, :i2c_module, Circuits.I2C)
    Application.put_env(:lcd_display, :spi_module, Circuits.SPI)

    on_exit(fn ->
      # Restore original config
      Application.put_env(:lcd_display, :gpio_module, original_gpio)
      Application.put_env(:lcd_display, :i2c_module, original_i2c)
      Application.put_env(:lcd_display, :spi_module, original_spi)
    end)

    :ok
  end

  describe "Circuits library compilation and basic API compatibility" do
    test "circuits_gpio compiles and basic API is available" do
      # Test that the module loads and basic functions exist
      assert Code.ensure_loaded?(Circuits.GPIO)

      # Test basic type definitions are available
      assert function_exported?(Circuits.GPIO, :open, 2)
      assert function_exported?(Circuits.GPIO, :write, 2)
      assert function_exported?(Circuits.GPIO, :close, 1)

      # Test that we can call the backend info (new in v2.x)
      # This will fail gracefully if no hardware is present
      case Circuits.GPIO.backend_info() do
        %{name: _backend} = info when is_map(info) -> :ok
        error -> flunk("Unexpected backend_info response: #{inspect(error)}")
      end
    end

    test "circuits_i2c compiles and basic API is available" do
      # Test that the module loads and basic functions exist
      assert Code.ensure_loaded?(Circuits.I2C)

      # Test basic functions are available
      assert function_exported?(Circuits.I2C, :open, 1)
      assert function_exported?(Circuits.I2C, :write, 3)
      assert function_exported?(Circuits.I2C, :close, 1)

      # Test that opening a non-existent bus fails gracefully
      case Circuits.I2C.open("i2c-nonexistent") do
        {:error, _reason} ->
          :ok

        {:ok, ref} ->
          Circuits.I2C.close(ref)
          :ok
      end
    end

    test "circuits_spi compiles and basic API is available" do
      # Test that the module loads and basic functions exist
      assert Code.ensure_loaded?(Circuits.SPI)

      # Test basic functions are available
      assert function_exported?(Circuits.SPI, :open, 1)
      assert function_exported?(Circuits.SPI, :open, 2)
      assert function_exported?(Circuits.SPI, :transfer, 2)
      assert function_exported?(Circuits.SPI, :close, 1)

      # Test that opening a non-existent SPI device fails gracefully
      case Circuits.SPI.open("spidev99.99") do
        {:error, _reason} ->
          :ok

        {:ok, ref} ->
          Circuits.SPI.close(ref)
          :ok
      end
    end

    test "LcdDisplay wrappers work with upgraded circuits libraries" do
      # Test GPIO wrapper
      case LcdDisplay.GPIO.open(18, :output) do
        {:ok, ref} ->
          assert :ok = LcdDisplay.GPIO.write(ref, 1)
          :ok

        # Expected without hardware
        {:error, _reason} ->
          :ok
      end

      # Test I2C wrapper
      case LcdDisplay.I2C.open("i2c-1") do
        {:ok, ref} ->
          # This should fail gracefully without hardware
          case LcdDisplay.I2C.write(ref, 0x20, <<0x00>>) do
            :ok -> :ok
            {:error, _reason} -> :ok
          end

        # Expected without hardware
        {:error, _reason} ->
          :ok
      end

      # Test SPI wrapper
      case LcdDisplay.SPI.open("spidev0.0") do
        {:ok, ref} ->
          case LcdDisplay.SPI.transfer(ref, <<0x00>>) do
            {:ok, _data} -> :ok
            {:error, _reason} -> :ok
          end

        # Expected without hardware
        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "Version compatibility checks" do
    test "circuits libraries are at expected major versions" do
      # Check that we're actually using the upgraded versions
      gpio_version = Application.spec(:circuits_gpio, :vsn) |> to_string()
      i2c_version = Application.spec(:circuits_i2c, :vsn) |> to_string()
      spi_version = Application.spec(:circuits_spi, :vsn) |> to_string()

      assert String.starts_with?(gpio_version, "2."),
             "Expected circuits_gpio v2.x, got #{gpio_version}"

      assert String.starts_with?(i2c_version, "2."),
             "Expected circuits_i2c v2.x, got #{i2c_version}"

      assert String.starts_with?(spi_version, "2."),
             "Expected circuits_spi v2.x, got #{spi_version}"
    end
  end
end
