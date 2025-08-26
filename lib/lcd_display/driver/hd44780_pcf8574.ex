defmodule LcdDisplay.HD44780.PCF8574 do
  @moduledoc """
  Knows how to commuticate with HD44780 type display through the 8-bit I/O expander
  [PCF8574](https://www.nxp.com/docs/en/data-sheet/PCF8574_PCF8574A.pdf).
  You can turn on/off the backlight.

  ## Usage

  ```
  iex(2)>  Circuits.I2C.detect_devices
  Devices on I2C bus "i2c-1":
  * 39  (0x27)

  1 devices detected on 1 I2C buses
  ```

  ```
  config = %{
    i2c_bus: "i2c-1",          # I2C bus name
    i2c_address: 0x27,         # 7-bit address
    rows: 2,                   # the number of display rows
    cols: 16,                  # the number of display columns
    font_size: "5x8"           # "5x10" or "5x8"
  }

  # Start the LCD driver and get the initial display state.
  {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

  # Run a command and the display state will be updated.
  {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Hello world"})
  ```

  ## Backlight Control Options

  The driver supports three backlight control modes:

  * `:auto` (default) - Library manages backlight state automatically
  * `:manual` - Preserves current backlight state during LCD operations
  * `:off` - Never sets backlight bit (always off)

  ### Manual Backlight Control

  For external backlight control (e.g., direct I2C writes), use `:manual` mode:

  ```
  config = %{
    i2c_bus: "i2c-1",
    i2c_address: 0x27,
    rows: 2,
    cols: 16,
    backlight_control: :manual,
    initial_backlight: false
  }

  {:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

  # LCD operations won't change backlight state
  {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Hello"})

  # Change backlight control mode at runtime
  {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :manual})

  # Sync library state with external backlight control
  {:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})
  ```

  ## Pin assignment

  This module assumes the following pin assignment:

  | PCF8574 | HD44780              |
  | ------- | -------------------- |
  | P0      | RS (Register Select) |
  | P1      | -                    |
  | P2      | E (Enable)           |
  | P3      | LED                  |
  | P4      | DB4 (Data Bus 4)     |
  | P5      | DB5 (Data Bus 5)     |
  | P6      | DB6 (Data Bus 6)     |
  | P7      | DB7 (Data Bus 7)     |
  """

  use LcdDisplay.HD44780.Driver

  @default_i2c_bus "i2c-1"
  @default_i2c_address 0x27
  @enable_bit 0x04
  @backlight_on 0x08

  @type display_driver :: LcdDisplay.HD44780.Driver.t()

  @typedoc """
  The configuration options.
  """
  @type config :: %{
          optional(:rows) => String.t(),
          optional(:cols) => pos_integer,
          optional(:font_size) => pos_integer,
          optional(:backlight_control) => :auto | :manual | :off,
          optional(:initial_backlight) => boolean
        }

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @impl LcdDisplay.HD44780.Driver
  @spec start(config) :: {:ok, display_driver} | {:error, any}
  def start(config) do
    number_of_lines = if config[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if config[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    {:ok,
     config
     |> initial_state()
     |> initialize_display_with_backlight()
     |> initialize_display(function_set: @cmd_function_set ||| font_size ||| number_of_lines)}
  rescue
    e -> {:error, e}
  end

  @spec initial_state(config) :: display_driver | no_return
  defp initial_state(opts) do
    i2c_bus = opts[:i2c_bus] || @default_i2c_bus
    i2c_address = opts[:i2c_address] || @default_i2c_address
    {:ok, i2c_ref} = initialize_serial_bus(i2c_bus, i2c_address)

    %{
      driver_module: __MODULE__,
      i2c_ref: i2c_ref,
      i2c_address: i2c_address,
      rows: opts[:rows] || @default_rows,
      cols: opts[:cols] || @default_cols,

      # Initial values for features that we can change later.
      entry_mode: @cmd_entry_mode_set ||| @entry_left,
      display_control: @cmd_display_control ||| @display_on,
      backlight: if(opts[:initial_backlight] != nil, do: opts[:initial_backlight], else: true),
      backlight_control: opts[:backlight_control] || :auto
    }
  end

  @spec initialize_serial_bus(String.t(), byte) :: {:ok, reference} | no_return
  defp initialize_serial_bus(i2c_bus, _i2c_address) do
    {:ok, _i2c_ref} = LcdDisplay.I2C.open(i2c_bus)
  end

  # Initializes the display for 4-bit interface. See Hitachi HD44780 datasheet page 46 for details.
  @spec initialize_display(display_driver, list) :: display_driver | no_return
  defp initialize_display(display, function_set: function_set) do
    display
    # Function set (8-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(1)

    # Function set (4-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x02)

    # Function set (4-bit mode; Interface is 4 bits long)
    # The number of display lines and character font cannot be changed after this point.
    |> write_instruction(function_set)
    |> write_feature(:display_control)
    |> clear()
    |> write_feature(:entry_mode)
  end

  @doc """
  Executes the specified command and returns a new display state.
  """
  @impl LcdDisplay.HD44780.Driver
  def execute(display, :clear), do: {:ok, clear(display)}
  def execute(display, :home), do: {:ok, home(display)}
  def execute(display, {:print, text}), do: {:ok, print(display, text)}
  def execute(display, {:set_cursor, row, col}), do: {:ok, set_cursor(display, row, col)}
  def execute(display, {:cursor, on_off_bool}), do: {:ok, set_display_control_flag(display, @cursor_on, on_off_bool)}
  def execute(display, {:blink, on_off_bool}), do: {:ok, set_display_control_flag(display, @blink_on, on_off_bool)}
  def execute(display, {:display, on_off_bool}), do: {:ok, set_display_control_flag(display, @display_on, on_off_bool)}
  def execute(display, {:autoscroll, on_off_bool}), do: {:ok, set_entry_mode_flag(display, @autoscroll, on_off_bool)}
  def execute(display, {:text_direction, :right_to_left}), do: {:ok, set_entry_mode_flag(display, @entry_left, false)}
  def execute(display, {:text_direction, :left_to_right}), do: {:ok, set_entry_mode_flag(display, @entry_left, true)}
  def execute(display, {:scroll, cols}), do: {:ok, scroll(display, cols)}
  def execute(display, {:right, cols}), do: {:ok, right(display, cols)}
  def execute(display, {:left, cols}), do: {:ok, left(display, cols)}
  def execute(display, {:backlight, on_off_bool}), do: {:ok, set_backlight(display, on_off_bool)}

  def execute(display, {:backlight_control, mode}) when mode in [:auto, :manual, :off],
    do: {:ok, set_backlight_control(display, mode)}

  def execute(display, {:sync_backlight_state, on_off_bool}), do: {:ok, sync_backlight_state(display, on_off_bool)}
  def execute(_display, command), do: {:error, {:unsupported, command}}

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(2)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(2)

  defp print(display, char) when is_integer(char), do: write_data(display, char)

  defp print(display, text) when is_binary(text) do
    # Translates a text to a charlist (list of bytes).
    text |> to_charlist() |> Enum.each(&write_data(display, &1))
    display
  end

  # Set the DDRAM address corresponding to the specified cursor position.
  @spec set_cursor(display_driver, pos_integer, pos_integer) :: display_driver
  defp set_cursor(display, row, col) when row >= 0 and col >= 0 do
    ddram_address = determine_ddram_address({row, col}, Map.take(display, [:rows, :cols]))
    write_instruction(display, @cmd_set_ddram_address ||| ddram_address)
  end

  @spec set_entry_mode_flag(display_driver, byte, boolean) :: display_driver
  defp set_entry_mode_flag(display, flag, on_off_bool) do
    entry_mode =
      if on_off_bool,
        do: display.entry_mode ||| flag,
        else: display.entry_mode &&& ~~~flag

    write_feature(%{display | entry_mode: entry_mode}, :entry_mode)
  end

  @spec set_display_control_flag(display_driver, byte, boolean) :: display_driver
  defp set_display_control_flag(display, flag, on_off_bool) do
    display_control =
      if on_off_bool,
        do: display.display_control ||| flag,
        else: display.display_control &&& ~~~flag

    write_feature(%{display | display_control: display_control}, :display_control)
  end

  # Write a feature based on the display state.
  @spec write_feature(display_driver, LcdDisplay.HD44780.Driver.feature()) :: display_driver
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    display |> write_instruction(Map.fetch!(display, feature_key))
  end

  defp scroll(display, 0), do: display

  # Scroll the entire display left
  defp scroll(display, cols) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display)
    scroll(display, cols + 1)
  end

  # Scroll the entire display right
  defp scroll(display, cols) when cols > 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display ||| @shift_right)
    scroll(display, cols - 1)
  end

  # Move cursor right
  defp right(display, 0), do: display

  defp right(display, cols) do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_right)
    right(display, cols - 1)
  end

  # Move cursor left
  defp left(display, 0), do: display

  defp left(display, cols) do
    write_instruction(display, @cmd_cursor_shift_control)
    left(display, cols - 1)
  end

  @spec set_backlight(display_driver, boolean) :: display_driver
  defp set_backlight(display, flag) when is_boolean(flag) do
    # Set backlight and write 0 (nothing) to trigger it.
    %{display | backlight: flag} |> expander_write(0)
  end

  @spec set_backlight_control(display_driver, :auto | :manual | :off) :: display_driver
  defp set_backlight_control(display, mode) when mode in [:auto, :manual, :off] do
    %{display | backlight_control: mode}
  end

  @spec sync_backlight_state(display_driver, boolean) :: display_driver
  defp sync_backlight_state(display, flag) when is_boolean(flag) do
    %{display | backlight: flag}
  end

  @impl LcdDisplay.HD44780.Driver
  def write_instruction(display, byte), do: write_byte(display, byte, 0)

  @impl LcdDisplay.HD44780.Driver
  def write_data(display, byte), do: write_byte(display, byte, 1)

  @spec write_byte(display_driver, byte, 0..1) :: display_driver
  defp write_byte(display, byte, rs_bit) when byte in 0..255 and rs_bit in 0..1 do
    <<high_four_bits::4, low_four_bits::4>> = <<byte>>

    display
    |> write_four_bits(high_four_bits, rs_bit)
    |> write_four_bits(low_four_bits, rs_bit)
  end

  @spec write_four_bits(display_driver, 0..15, 0..1) :: display_driver
  defp write_four_bits(display, four_bits, rs_bit \\ 0)
       when is_integer(four_bits) and four_bits in 0..15 and rs_bit in 0..1 do
    # Map the four bits to the data pins.
    <<d7::1, d6::1, d5::1, d4::1>> = <<four_bits::4>>
    <<data_byte>> = <<d7::1, d6::1, d5::1, d4::1, 0::1, 0::1, 0::1, rs_bit::1>>

    display
    |> expander_write(data_byte)
    |> pulse_enable(data_byte)
  end

  @spec pulse_enable(display_driver, byte) :: display_driver
  defp pulse_enable(display, byte) do
    display
    |> expander_write(byte ||| @enable_bit)
    |> expander_write(byte &&& ~~~@enable_bit)
  end

  @spec initialize_display_with_backlight(display_driver) :: display_driver
  defp initialize_display_with_backlight(display) do
    case display.backlight_control do
      :auto -> expander_write(display, if(display.backlight, do: @backlight_on, else: 0))
      _ -> expander_write(display, 0)
    end
  end

  @spec expander_write(display_driver, byte) :: display_driver
  defp expander_write(display, byte) when is_integer(byte) do
    %{i2c_ref: i2c_ref, i2c_address: i2c_address, backlight: backlight, backlight_control: backlight_control} = display

    data =
      case backlight_control do
        # Never set backlight bit
        :off -> byte
        # Don't modify backlight bit - preserve current hardware state
        :manual -> byte
        # Default behavior
        :auto -> if backlight, do: byte ||| @backlight_on, else: byte
      end

    :ok = LcdDisplay.I2C.write(i2c_ref, i2c_address, [data])
    display
  end
end
