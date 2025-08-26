defmodule LcdDisplay.HD44780.PCF8574Test do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.HD44780

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Mox.stub_with(LcdDisplay.MockI2C, LcdDisplay.I2C.Stub)
    :ok
  end

  test "LcdDisplay.I2C mock works" do
    assert {:ok, i2c_ref} = LcdDisplay.I2C.open("i2c-1")
    assert :ok = LcdDisplay.I2C.write(i2c_ref, 0x20, <<0x00, 0x0F>>)
  end

  test "start with blank options" do
    assert {:ok, display} = HD44780.PCF8574.start(%{})

    assert %{
             driver_module: LcdDisplay.HD44780.PCF8574,
             i2c_address: 0x27,
             i2c_ref: i2c_ref,
             rows: 2,
             cols: 16,
             entry_mode: 6,
             display_control: 12,
             backlight: true,
             backlight_control: :auto
           } = display

    assert is_reference(i2c_ref)
  end

  test "start with some options" do
    opts = %{i2c_address: 0x3F, rows: 4, cols: 20}
    {:ok, display} = HD44780.PCF8574.start(opts)
    assert %{i2c_address: 0x3F, rows: 4, cols: 20} = display
  end

  test "start with backlight control options" do
    opts = %{backlight_control: :manual, initial_backlight: false}
    {:ok, display} = HD44780.PCF8574.start(opts)
    assert %{backlight: false, backlight_control: :manual} = display
  end

  describe "commands" do
    setup do
      with {:ok, display} <- HD44780.PCF8574.start(%{}), do: %{display: display}
    end

    test "execute valid commands", %{display: d} do
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, :clear)
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, :home)
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:print, "Hello"})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:set_cursor, 2, 2})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:cursor, false})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:cursor, true})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:blink, false})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:blink, true})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:autoscroll, false})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:autoscroll, true})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:scroll, 2})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:left, 2})
      assert {:ok, %{}} = HD44780.PCF8574.execute(d, {:right, 2})
    end

    test "execute unsupported commands", %{display: d} do
      assert {:error, {:unsupported, _command}} = HD44780.PCF8574.execute(d, {:write, 'H'})
      assert {:error, {:unsupported, _command}} = HD44780.PCF8574.execute(d, {:text_direction, false})
      assert {:error, {:unsupported, _command}} = HD44780.PCF8574.execute(d, {:char, "invalid args"})
    end

    test "change entry_mode", %{display: d} do
      assert {:ok, %{entry_mode: 4}} = HD44780.PCF8574.execute(d, {:text_direction, :right_to_left})
      assert {:ok, %{entry_mode: 6}} = HD44780.PCF8574.execute(d, {:text_direction, :left_to_right})
    end

    test "change display_control", %{display: d} do
      assert {:ok, %{display_control: 8}} = HD44780.PCF8574.execute(d, {:display, false})
      assert {:ok, %{display_control: 12}} = HD44780.PCF8574.execute(d, {:display, true})
    end

    test "change backlight", %{display: d} do
      assert {:ok, %{backlight: false}} = HD44780.PCF8574.execute(d, {:backlight, false})
      assert {:ok, %{backlight: true}} = HD44780.PCF8574.execute(d, {:backlight, true})
    end

    test "change backlight control mode", %{display: d} do
      assert {:ok, %{backlight_control: :manual}} = HD44780.PCF8574.execute(d, {:backlight_control, :manual})
      assert {:ok, %{backlight_control: :off}} = HD44780.PCF8574.execute(d, {:backlight_control, :off})
      assert {:ok, %{backlight_control: :auto}} = HD44780.PCF8574.execute(d, {:backlight_control, :auto})
    end

    test "sync backlight state", %{display: d} do
      assert {:ok, %{backlight: false}} = HD44780.PCF8574.execute(d, {:sync_backlight_state, false})
      assert {:ok, %{backlight: true}} = HD44780.PCF8574.execute(d, {:sync_backlight_state, true})
    end

    test "manual backlight control preserves state during LCD operations", %{display: d} do
      # Set to manual mode with backlight off
      {:ok, d} = HD44780.PCF8574.execute(d, {:backlight_control, :manual})
      {:ok, d} = HD44780.PCF8574.execute(d, {:sync_backlight_state, false})

      # LCD operations should not change backlight state
      {:ok, d} = HD44780.PCF8574.execute(d, :clear)
      assert %{backlight: false} = d

      {:ok, d} = HD44780.PCF8574.execute(d, {:print, "Test"})
      assert %{backlight: false} = d

      {:ok, d} = HD44780.PCF8574.execute(d, {:set_cursor, 1, 0})
      assert %{backlight: false} = d
    end

    test "off mode never sets backlight", %{display: d} do
      # Set to off mode
      {:ok, d} = HD44780.PCF8574.execute(d, {:backlight_control, :off})
      {:ok, d} = HD44780.PCF8574.execute(d, {:sync_backlight_state, true})

      # LCD operations should not affect backlight
      {:ok, d} = HD44780.PCF8574.execute(d, :clear)
      {:ok, d} = HD44780.PCF8574.execute(d, {:print, "Test"})

      # Internal state can be true, but hardware backlight should be off
      assert %{backlight: true, backlight_control: :off} = d
    end
  end
end
