
class HT16K33Segment
{
	// HT16K33 registers and HT16K33-specific constants

	HT16K33_REGISTER_DISPLAY_ON  = "\x81"
	HT16K33_REGISTER_DISPLAY_OFF = "\x80"
	HT16K33_REGISTER_SYSTEM_ON   = "\x21"
	HT16K33_REGISTER_SYSTEM_OFF  = "\x20"
	HT16K33_DISPLAY_ADDRESS      = "\x00"
	HT16K33_I2C_ADDRESS = 0x70
	HT16K33_BLANK_CHAR = 16
	HT16K33_MINUS_CHAR = 17
	HT16K33_CHAR_COUNT = 17

	// Class properties; those defined in the Constructor must be null

	_buffer = null
	_digits = null
	_led = null
	_ledAddress = 0

	constructor(impBus = null, i2cAddress = 0x70)
	{
		// Parameters:
		// 1. Whichever *configured* imp I2C bus is to be used for the HT16K33
		// 2. The HT16K33's I2C address (default: 0x70)

		if (impBus == null) return null
    
		_led = impBus
		_ledAddress = i2cAddress << 1

		// _buffer stores the character matrix values for each row of the display,
		// Including the center colon character
		//
		//  0    1   2   3    4
		// [ ]  [ ]  .  [ ]  [ ]
		//  -    -       -    -
		// [ ]  [ ]  .  [ ]  [ ]

		_buffer = [0x00, 0x00, 0x00, 0x00, 0x00]

		// _digits store character matrices for 0-9, A-F, blank and minus

		_digits = 
		[0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,  // 0-9
		0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71,  // A-F
		0x00, 0x40] // Space and minus symbol
		
		init()
	}

	function init(clearChar = 16, brightness = 15, showColon = false)
	{
		// Parameters:
		// 1. Integer index for the _digits[] character matrix to zero the display to
		// 2. Integer value for the display brightness, between 0 and 15
		// 3. Boolean value - should the colon (_digits[2]) be shown?

		// Set the brightness (which of necessity power cyles the dispay)
    
    if (brightness < 0) brightness = 0
    if (brightness > 15) brightness = 15
		setBrightness(brightness)

		// Clear the screen to the chosen character
    
    if (clearChar < 0 || clearChar > HT16K33_CHAR_COUNT) clearChar = HT16K33_BLANK_CHAR
		clearBuffer(clearChar)
		setColon(showColon)
		updateDisplay()
	}

	function clearBuffer(clearChar = 16)
	{
		// Fills the buffer with a blank character, or the _digits[] character matrix whose index is provided

		if (clearChar < 0 || clearChar > HT16K33_CHAR_COUNT) clearChar = HT16K33_BLANK_CHAR

		// Put the clearCharacter into the buffer except row 2 (colon row)

		_buffer[0] = _digits[clearChar]
		_buffer[1] = _digits[clearChar]
		_buffer[3] = _digits[clearChar]
		_buffer[4] = _digits[clearChar]
	}

	function setColon(set)
	{
		// Shows or hides the colon row (display row 2) according to the passed bool

		_buffer[2] = 0x00
		if (set) _buffer[2] = 0xFF
	}

	function writeChar(rowNum = 0, charVal = 0x7F, hasDot = false)
	{
		// Puts the input character matrix (an 8-bit integer) into the specified row,
		// adding a decimal point if required. Character matrix value is calculated by
		// setting the bit(s) representing the segment(s) you want illuminated.
		// Bit-to-segment mapping runs clockwise from the top around the outside of the
		// matrix; the inner segment is bit 6:
		//
		//	    0
		//	    _
		//	5 |   | 1
		//	  |   |
		//	    - <----- 6
		//	4 |   | 2
		//	  | _ |
		//	    3
		//
		// Bit 7 is the period, but this is set with parameter 3

		if (rowNum < 0 || rowNumber > 4) return
		if (hasDot) charVal = charVal | 0x80
		_buffer[rowNum] = charVal
	}

	function writeNumber(rowNum = 0, intVal = 0, hasDot = false)
	{
		// Puts the number - ie. index of _digits[] - into the specified row,
		// adding a decimal point if required

		if (rowNum < 0 || rowNum > 4) return
		if (intVal < 0 || intVal > 15) return

		if (hasDot)
		{
			_buffer[rowNum] = _digits[intVal] | 0x80
		}
		else
		{
			_buffer[rowNum] = _digits[intVal]
		}
	}

	function updateDisplay()
	{
		// Converts the row-indexed buffer[] values into a single, combined
		// string and writes it to the HT16K33 via I2C

		local dataString = HT16K33_DISPLAY_ADDRESS

		for (local i = 0 ; i < 5 ; i++)
		{
			dataString = dataString + _buffer[i].tochar() + "\x00"
		}

		// Write the combined datastring to I2C

		_led.write(_ledAddress, dataString)
	}

	function setBrightness(brightness = 15)
	{
		// This function is called when the app changes the clock's brightness
		// Default: 15

		if (brightness > 15) brightness = 15
		if (brightness < 0) brightness = 0

		brightness = brightness + 224

		// Preserve the buffer contents before wiping the display

		local sbuffer = [0,0,0,0,0]

		foreach (index, value in _buffer)
		{
		    sbuffer[index] = _buffer[index]
		}

		clearBuffer(HT16K33_BLANK_CHAR)
		updateDisplay()

		// Power cycle the display

		powerDown()
		powerUp()

    // Write the new brightness value to the HT16K33

		_led.write(_ledAddress, brightness.tochar() + "\x00")
		
		// Restore the buffer and display it
		
    foreach (index, value in sbuffer)
		{
		    _buffer[index] = sbuffer[index]
		}

    updateDisplay()
	}

	function powerDown()
	{
		_led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_OFF)
		_led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_OFF)
	}

	function powerUp()
	{
		_led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_ON)
		_led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_ON)
	}
}
