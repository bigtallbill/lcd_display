# LCD Backlight Control Fix

## Problem Summary

The `lcd_display` library had an issue where LCD operations (`:clear`, `:print`, `:set_cursor`, etc.) would inadvertently turn the LCD backlight back on, overriding manual backlight control via direct I2C writes to the PCF8574.

### Root Cause

The PCF8574 driver maintained its own internal backlight state (`display.backlight`) and applied this state on every I2C write operation. When external code controlled the backlight directly via I2C writes, the library's internal state became out of sync. Subsequent LCD operations would restore the library's internal backlight state, turning the backlight back on unexpectedly.

## Solution

Added three backlight control modes to the PCF8574 driver:

- **`:auto`** (default) - Library manages backlight state automatically (original behavior)
- **`:manual`** - Preserves current backlight state during LCD operations  
- **`:off`** - Never sets backlight bit (always off)

## New Configuration Options

### `backlight_control`
Controls how the library handles the backlight bit during LCD operations.

- `:auto` - Default behavior, library controls backlight
- `:manual` - Library preserves current hardware backlight state
- `:off` - Library never sets backlight bit

### `initial_backlight`
Sets the initial backlight state when the driver starts (boolean).

## New API Commands

### `{:backlight_control, mode}`
Changes the backlight control mode at runtime.

```elixir
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :manual})
```

### `{:sync_backlight_state, boolean}`
Synchronizes the library's internal backlight state with external control.

```elixir
# After external backlight control, sync the library state
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})
```

## Usage Examples

### Manual Backlight Control

For applications that need external backlight control:

```elixir
config = %{
  i2c_bus: "i2c-1",
  i2c_address: 0x27,
  rows: 2,
  cols: 16,
  backlight_control: :manual,    # Prevent automatic backlight management
  initial_backlight: false       # Start with backlight off
}

{:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

# LCD operations won't change backlight state
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Hello"})
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:set_cursor, 1, 0})

# External backlight control via direct I2C
{:ok, i2c_ref} = Circuits.I2C.open("i2c-1")
:ok = Circuits.I2C.write(i2c_ref, 0x27, [0x08])  # Turn on backlight
:ok = Circuits.I2C.write(i2c_ref, 0x27, [0x00])  # Turn off backlight

# Sync library state if needed
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:sync_backlight_state, false})
```

### Always Off Backlight

For power-sensitive applications:

```elixir
config = %{
  i2c_bus: "i2c-1",
  i2c_address: 0x27,
  rows: 2,
  cols: 16,
  backlight_control: :off        # Never turn on backlight
}

{:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

# All LCD operations will keep backlight off
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Low Power Mode"})
```

### Runtime Mode Changes

Switch between modes during operation:

```elixir
# Start in auto mode
{:ok, display} = LcdDisplay.HD44780.PCF8574.start(%{})

# Switch to manual control
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :manual})

# Do external backlight control...

# Switch back to auto mode
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:backlight_control, :auto})
```

## Backward Compatibility

This fix is fully backward compatible. Existing code will continue to work without changes, as the default behavior (`:auto` mode) matches the original implementation.

## Technical Details

### Changes Made

1. **Enhanced `expander_write/2` function** - Now respects the backlight control mode
2. **New configuration options** - `backlight_control` and `initial_backlight`
3. **New API commands** - `:backlight_control` and `:sync_backlight_state`
4. **Fixed initialization** - Respects initial backlight configuration
5. **Comprehensive tests** - Added test coverage for all new functionality

### PCF8574 Pin Mapping

The fix maintains the existing pin assignment:

| PCF8574 | HD44780              |
| ------- | -------------------- |
| P0      | RS (Register Select) |
| P1      | -                    |
| P2      | E (Enable)           |
| P3      | LED (Backlight)      |
| P4      | DB4 (Data Bus 4)     |
| P5      | DB5 (Data Bus 5)     |
| P6      | DB6 (Data Bus 6)     |
| P7      | DB7 (Data Bus 7)     |

Bit 3 (0x08) controls the backlight state.

## Testing

Run the test suite to verify the fix:

```bash
mix test test/lcd_display/driver/hd44780_pcf8574_test.exs
```

Or run the demo script:

```bash
elixir examples/backlight_control/manual_backlight_demo.exs
```

## Migration Guide

### For Manual Backlight Control

If you were using the workaround of calling `set_backlight_direct()` after every LCD operation:

**Before:**
```elixir
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
set_backlight_direct(false)  # Restore backlight state

{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Text"})
set_backlight_direct(false)  # Restore backlight state again
```

**After:**
```elixir
# Configure once at startup
config = %{
  # ... other config
  backlight_control: :manual,
  initial_backlight: false
}
{:ok, display} = LcdDisplay.HD44780.PCF8574.start(config)

# No need to restore backlight state after each operation
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, :clear)
{:ok, display} = LcdDisplay.HD44780.PCF8574.execute(display, {:print, "Text"})

# External backlight control works without interference
set_backlight_direct(false)
```

This eliminates I2C bus contention and improves performance.