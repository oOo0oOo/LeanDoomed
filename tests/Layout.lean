import SDL

@[export test_column_x]
def column_x (c : SDL.DrawColumn) : Int32 := c.x

@[export test_column_y]
def column_y (c : SDL.DrawColumn) : Int32 := c.y

@[export test_column_height]
def column_height (c : SDL.DrawColumn) : Int32 := c.height

@[export test_column_texX]
def column_texX (c : SDL.DrawColumn) : Int32 := c.texX

@[export test_column_texYStart]
def column_texYStart (c : SDL.DrawColumn) : Int32 := c.texYStart

@[export test_column_texYEnd]
def column_texYEnd (c : SDL.DrawColumn) : Int32 := c.texYEnd

@[export test_column_shade]
def column_shade (c : SDL.DrawColumn) : UInt8 := c.shade

