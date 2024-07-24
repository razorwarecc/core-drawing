if not LPH_OBFUSCATED then
    LPH_CRASH = function() while true do end end
    LPH_ENCNUM = function(n) return n end
    LPH_ENCSTR = function(s) return s end
    LPH_JIT = function(f) return f end
    LPH_NO_VIRTUALIZE = function(f) return f end
    LPH_NO_UPVALUES = function(f) return f end
end

LPH_NO_VIRTUALIZE(function()

    assert(getcustomasset, "This enviornment does not support 'getcustomasset'!")
    assert(gethui, "This enviornment does not support 'gethui'!")
    assert(isfolder, "This enviornment does not support 'isfolder'!")
    assert(makefolder, "This enviornment does not support 'makefolder'!")
    assert(isfile, "This enviornment does not support 'isfile'!")
    assert(delfile, "This enviornment does not support 'delfile'!")
    assert(readfile, "This enviornment does not support 'readfile'!")
    assert(writefile, "This enviornment does not support 'writefile'!")
    assert(crypt, "This enviornment does not support 'crypt'!")

    if cleardrawcache then
        cleardrawcache()
    end

    local env = getgenv and getgenv() or _G
    local cloneref = cloneref or function(v) return v end
    local clonefunction = clonefunction or function(v) return v end

    -- // Variables
    local TextService = cloneref(game:GetService("TextService"))
    local HttpService = cloneref(game:GetService("HttpService"))

    local HttpGet = clonefunction(game.HttpGet)
    local GetTextBoundsAsync = clonefunction(TextService.GetTextBoundsAsync)

    local math = {
        atan2 = clonefunction(math.atan2),
        clamp = clonefunction(math.clamp),
        max = clonefunction(math.max),
        min = clonefunction(math.min),
        pi = math.pi,
        huge = math.huge
    }

    local string = {
        format = clonefunction(string.format),
        sub = clonefunction(string.sub)
    }

    local UDim2 = {
        new = clonefunction(UDim2.new),
        fromOffset = clonefunction(UDim2.fromOffset),
        fromScale = clonefunction(UDim2.fromScale)
    }

    local Vector2 = {
        new = clonefunction(Vector2.new),
        zero = Vector2.zero
    }

    local Color3 = {
        new = clonefunction(Color3.new),
    }

    -- // Drawing
    local Drawing = {}

    Drawing.__CLASSES = {}
    Drawing.__OBJECT_CACHE = {}
    Drawing.__IMAGE_CACHE = {}

    Drawing.Font = {
        Count = 0,
        Fonts = {},
        Enums = {}
    }

    function Drawing.new(class)
        if not Drawing.__CLASSES[class] then
            error(`Invalid argument #1, expected a valid drawing type`, 2)
        end

        return Drawing.__CLASSES[class].new()
    end

    function Drawing.Font.new(FontName, FontData)

        local FontID = Drawing.Font.Count
        local FontObject

        Drawing.Font.Count += 1
        Drawing.Font.Fonts[FontName] = FontID

        if string.sub(FontData, 1, 11) == "rbxasset://" then
            FontObject = Font.new(FontData, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        else
            local TempPath = HttpService:GenerateGUID(false)

            if not isfile(FontData) then
                writefile(`DrawingFontCache/{FontName}.ttf`, crypt.base64.decode(FontData))
                FontData = `DrawingFontCache/{FontName}.ttf`
            end
        
            writefile(TempPath, HttpService:JSONEncode({
                ["name"] = FontName,
                ["faces"] = {
                    {
                        ["name"] = "Regular",
                        ["weight"] = 100,
                        ["style"] = "normal",
                        ["assetId"] = getcustomasset(FontData)
                    }
                }
            }))

            FontObject = Font.new(getcustomasset(TempPath), Enum.FontWeight.Regular, Enum.FontStyle.Normal)

            delfile(TempPath)
        end

        if not FontObject then
            error("Internal Error while creating new font.", 2)
        end

        Drawing.__TEXT_BOUND_PARAMS.Text = "Text"
        Drawing.__TEXT_BOUND_PARAMS.Size = 12
        Drawing.__TEXT_BOUND_PARAMS.Font = FontObject
        Drawing.__TEXT_BOUND_PARAMS.Width = math.huge

        GetTextBoundsAsync(TextService, Drawing.__TEXT_BOUND_PARAMS) -- Preload/Cache font for GetTextBoundsAsync to avoid yielding across metamethods

        Drawing.Font.Enums[FontID] = FontObject

        return FontObject
    end

    function Drawing.CreateInstance(class, properties, children)
        local object = Instance.new(class)

        for property, value in properties or {} do
            object[property] = value
        end

        for idx, child in children or {} do
            child.Parent = object
        end

        return object
    end

    function Drawing.ClearCache()
        for idx, object in Drawing.__OBJECT_CACHE do
            if rawget(object, "__OBJECT_EXISTS") then
                object:Remove()
            end
        end
    end

    function Drawing.UpdatePosition(object, from, to, thickness)
        local center = (from + to) / 2
        local offset = to - from

        object.Position = UDim2.fromOffset(center.X, center.Y)
        object.Size = UDim2.fromOffset(offset.Magnitude, thickness)
        object.Rotation = math.atan2(offset.Y, offset.X) * 180 / math.pi
    end

    Drawing.__ROOT = Drawing.CreateInstance("ScreenGui", {
        IgnoreGuiInset = true,
        DisplayOrder = 10,
        Name = HttpService:GenerateGUID(false),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = gethui()
    })

    Drawing.__TEXT_BOUND_PARAMS = Drawing.CreateInstance("GetTextBoundsParams", { Width = math.huge })

    --#region Line
    local Line = {}

    Drawing.__CLASSES["Line"] = Line

    function Line.new()
        local LineObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                From = Vector2.zero,
                To = Vector2.zero,
                Thickness = 1,
                Transparency = 1,
                ZIndex = 0,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(0, 0, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            })
        }, Line)

        table.insert(Drawing.__OBJECT_CACHE, LineObject)

        return LineObject
    end

    function Line:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Line[property]
    end

    function Line:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties = self.__PROPERTIES

        Properties[property] = value

        if property == "Color" then
            self.__OBJECT.BackgroundColor3 = value
        elseif property == "From" then
            Drawing.UpdatePosition(self.__OBJECT, Properties.From, Properties.To, Properties.Thickness)
        elseif property == "To" then
            Drawing.UpdatePosition(self.__OBJECT, Properties.From, Properties.To, Properties.Thickness)
        elseif property == "Thickness" then
            self.__OBJECT.Size = UDim2.fromOffset(self.__OBJECT.AbsoluteSize.X, math.max(value, 1))
        elseif property == "Transparency" then
            self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
        elseif property == "Visible" then
            self.__OBJECT.Visible = value
        elseif property == "ZIndex" then
            self.__OBJECT.ZIndex = value
        end
    end

    function Line:__iter()
        return next, self.__PROPERTIES
    end

    function Line:__tostring()
        return "Drawing"
    end

    function Line:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Line:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Circle
    local Circle = {}

    Drawing.__CLASSES["Circle"] = Circle

    function Circle.new()
        local CircleObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                Position = Vector2.new(0, 0),
                NumSides = 0,
                Radius = 0,
                Thickness = 1,
                Transparency = 1,
                ZIndex = 0,
                Filled = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(0, 0, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0),
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("UICorner", {
                    Name = "_CORNER",
                    CornerRadius = UDim.new(1, 0)
                }),
                Drawing.CreateInstance("UIStroke", {
                    Name = "_STROKE",
                    Color = Color3.new(0, 0, 0),
                    Thickness = 1
                })
            }),
        }, Circle)

        table.insert(Drawing.__OBJECT_CACHE, CircleObject)

        return CircleObject
    end

    function Circle:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Circle[property]
    end

    function Circle:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties = self.__PROPERTIES

        Properties[property] = value

        if property == "Color" then
            self.__OBJECT.BackgroundColor3 = value
            self.__OBJECT._STROKE.Color = value
        elseif property == "Filled" then
            self.__OBJECT.BackgroundTransparency = value and 1 - Properties.Transparency or 1
        elseif property == "Position" then
            self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
        elseif property == "Radius" then
            self:__UPDATE_RADIUS()
        elseif property == "Thickness" then
            self:__UPDATE_RADIUS()
        elseif property == "Transparency" then
            self.__OBJECT._STROKE.Transparency = math.clamp(1 - value, 0, 1)
            self.__OBJECT.Transparency = Properties.Filled and math.clamp(1 - value, 0, 1) or self.__OBJECT.Transparency
        elseif property == "Visible" then
            self.__OBJECT.Visible = value
        elseif property == "ZIndex" then
            self.__OBJECT.ZIndex = value
        end
    end

    function Circle:__iter()
        return next, self.__PROPERTIES
    end

    function Circle:__tostring()
        return "Drawing"
    end

    function Circle:__UPDATE_RADIUS()
        local diameter = (self.__PROPERTIES.Radius * 2) - (self.__PROPERTIES.Thickness * 2)
        self.__OBJECT.Size = UDim2.fromOffset(diameter, diameter)
    end

    function Circle:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Circle:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Text
    local Text = {}

    Drawing.__CLASSES["Text"] = Text

    function Text.new()
        local TextObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(1, 1, 1),
                OutlineColor = Color3.new(0, 0, 0),
                Position = Vector2.new(0, 0),
                TextBounds = Vector2.new(0, 0),
                Text = "",
                Font = Drawing.Font.Enums[2],
                Size = 13,
                Transparency = 1,
                ZIndex = 0,
                Center = false,
                Outline = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("TextLabel", {
                TextColor3 = Color3.new(1, 1, 1),
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                FontFace = Drawing.Font.Enums[1],
                TextSize = 12,
                BackgroundTransparency = 1,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("UIStroke", {
                    Name = "_STROKE",
                    Color = Color3.new(0, 0, 0),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    Enabled = false,
                    Thickness = 1
                })
            })
        }, Text)

        table.insert(Drawing.__OBJECT_CACHE, TextObject)

        return TextObject
    end

    function Text:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Text[property]
    end

    function Text:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        if value == "TextBounds" then
            error("Attempt to modify read-only property", 2)
        end

        local Properties = self.__PROPERTIES

        Properties[property] = value

        if property == "Color" then
            self.__OBJECT.TextColor3 = value
        elseif property == "Position" then
            self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
        elseif property == "Size" then
            self.__OBJECT.TextSize = value - 1
            self:_UPDATE_TEXT_BOUNDS()
        elseif property == "Text" then
            self.__OBJECT.Text = value
            self:_UPDATE_TEXT_BOUNDS()
        elseif property == "Font" then
            if type(value) == "string" then
                value = Drawing.Font.Enums[Drawing.Font.Fonts[value]]
            elseif type(value) == "number" then
                value = Drawing.Font.Enums[value]
            end

            Properties.Font = value

            self.__OBJECT.FontFace = value
            self:_UPDATE_TEXT_BOUNDS()
        elseif property == "Outline" then
            self.__OBJECT._STROKE.Enabled = value
        elseif property == "OutlineColor" then
            self.__OBJECT._STROKE.Color = value
        elseif property == "Center" then
            self.__OBJECT.TextXAlignment = value and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        elseif property == "Transparency" then
            self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
        elseif property == "Visible" then
            self.__OBJECT.Visible = value
        elseif property == "ZIndex" then
            self.__OBJECT.ZIndex = value
        end
    end

    function Text:__iter()
        return next, self.__PROPERTIES
    end

    function Text:__tostring()
        return "Drawing"
    end

    function Text:_UPDATE_TEXT_BOUNDS()
        local Properties = self.__PROPERTIES

        Drawing.__TEXT_BOUND_PARAMS.Text = Properties.Text
        Drawing.__TEXT_BOUND_PARAMS.Size = Properties.Size - 1
        Drawing.__TEXT_BOUND_PARAMS.Font = Properties.Font
        Drawing.__TEXT_BOUND_PARAMS.Width = math.huge

        Properties.TextBounds = GetTextBoundsAsync(TextService, Drawing.__TEXT_BOUND_PARAMS)
    end

    function Text:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Text:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Square
    local Square = {}

    Drawing.__CLASSES["Square"] = Square

    function Square.new()
        local SquareObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                Position = Vector2.new(0, 0),
                Size = Vector2.new(0, 0),
                Rounding = 0,
                Thickness = 0,
                Transparency = 1,
                ZIndex = 0,
                Filled = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("Frame", {
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("UIStroke", {
                    Name = "_STROKE",
                    Color = Color3.new(0, 0, 0),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    Thickness = 1
                }),
                Drawing.CreateInstance("UICorner", {
                    Name = "_CORNER",
                    CornerRadius = UDim.new(0, 0)
                })
            })
        }, Square)

        table.insert(Drawing.__OBJECT_CACHE, SquareObject)

        return SquareObject
    end

    function Square:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Square[property]
    end

    function Square:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties = self.__PROPERTIES

        Properties[property] = value

        if property == "Color" then
            self.__OBJECT.BackgroundColor3 = value
            self.__OBJECT._STROKE.Color = value
        elseif property == "Position" then
            self:__UPDATE_SCALE()
        elseif property == "Size" then
            self:__UPDATE_SCALE()
        elseif property == "Thickness" then
            self.__OBJECT._STROKE.Thickness = value
            self.__OBJECT._STROKE.Enabled = not Properties.Filled
            self:__UPDATE_SCALE()
        elseif property == "Rounding" then
            self.__OBJECT._CORNER.CornerRadius = UDim.new(0, value)
        elseif property == "Filled" then
            self.__OBJECT._STROKE.Enabled = not value
            self.__OBJECT.BackgroundTransparency = value and 1 - Properties.Transparency or 1
        elseif property == "Transparency" then
            self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
        elseif property == "Visible" then
            self.__OBJECT.Visible = value
        elseif property == "ZIndex" then
            self.__OBJECT.ZIndex = value
        end
    end

    function Square:__iter()
        return next, self.__PROPERTIES
    end

    function Square:__tostring()
        return "Drawing"
    end

    function Square:__UPDATE_SCALE()
        local Properties = self.__PROPERTIES

        self.__OBJECT.Position = UDim2.fromOffset(Properties.Position.X + Properties.Thickness, Properties.Position.Y + Properties.Thickness)
        self.__OBJECT.Size = UDim2.fromOffset(Properties.Size.X - Properties.Thickness * 2, Properties.Size.Y - Properties.Thickness * 2)
    end

    function Square:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Square:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Image
    local Image = {}

    Drawing.__CLASSES["Image"] = Image

    function Image.new()
        local ImageObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                Position = Vector2.new(0, 0),
                Size = Vector2.new(0, 0),
                Data = "",
                Uri = "",
                Thickness = 0,
                Transparency = 1,
                ZIndex = 0,
                Filled = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("ImageLabel", {
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                Image = "",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("UICorner", {
                    Name = "_CORNER",
                    CornerRadius = UDim.new(0, 0)
                })
            })
        }, Image)

        table.insert(Drawing.__OBJECT_CACHE, ImageObject)

        return ImageObject
    end

    function Image:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Image[property]
    end

    function Image:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties = self.__PROPERTIES

        Properties[property] = value

        if property == "Data" then
            self:__SET_IMAGE(value)
        elseif property == "Uri" then
            self:__SET_IMAGE(value, true)
        elseif property == "Rounding" then
            self.__OBJECT._CORNER.CornerRadius = UDim.new(0, value)
        elseif property == "Color" then
            self.__OBJECT.ImageColor3 = value
        elseif property == "Position" then
            self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
        elseif property == "Size" then
            self.__OBJECT.Size = UDim2.fromOffset(value.X, value.Y)
        elseif property == "Transparency" then
            self.__OBJECT.ImageTransparency = math.clamp(1 - value, 0, 1)
        elseif property == "Visible" then
            self.__OBJECT.Visible = value
        elseif property == "ZIndex" then
            self.__OBJECT.ZIndex = value
        end
    end

    function Image:__iter()
        return next, self.__PROPERTIES
    end

    function Image:__tostring()
        return "Drawing"
    end

    function Image:__SET_IMAGE(data, isUri)
        task.spawn(function()
            if isUri then
                data = HttpGet(game, data, true)
            end

            if not Drawing.__IMAGE_CACHE[data] then
                local TempPath = HttpService:GenerateGUID(false)

                writefile(TempPath, data)
                Drawing.__IMAGE_CACHE[data] = getcustomasset(TempPath)
                delfile(TempPath)
            end

            self.__PROPERTIES.Data = Drawing.__IMAGE_CACHE[data]
            self.__OBJECT.Image = Drawing.__IMAGE_CACHE[data]
        end)
    end

    function Image:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Image:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Triangle
    local Triangle = {}

    Drawing.__CLASSES["Triangle"] = Triangle

    function Triangle.new()
        local TriangleObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                PointA = Vector2.new(0, 0),
                PointB = Vector2.new(0, 0),
                PointC = Vector2.new(0, 0),
                Thickness = 1,
                Transparency = 1,
                ZIndex = 0,
                Filled = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("Frame", {
                    Name = "_A",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                }),
                Drawing.CreateInstance("Frame", {
                    Name = "_B",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                }),
                Drawing.CreateInstance("Frame", {
                    Name = "_C",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                })
            })
        }, Triangle)

        table.insert(Drawing.__OBJECT_CACHE, TriangleObject)

        return TriangleObject
    end

    function Triangle:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Triangle[property]
    end

    function Triangle:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties, Object = self.__PROPERTIES, self.__OBJECT

        Properties[property] = value

        if property == "Color" then
            Object._A.BackgroundColor3 = value
            Object._B.BackgroundColor3 = value
            Object._C.BackgroundColor3 = value
        elseif property == "Transparency" then
            Object._A.BackgroundTransparency = 1 - values
            Object._B.BackgroundTransparency = 1 - values
            Object._C.BackgroundTransparency = 1 - values
        elseif property == "Thickness" then
            Object._A.BackgroundColor3 = UDim2.fromOffset(Object._A.AbsoluteSize.X, math.max(value, 1));
            Object._B.BackgroundColor3 = UDim2.fromOffset(Object._B.AbsoluteSize.X, math.max(value, 1));
            Object._C.BackgroundColor3 = UDim2.fromOffset(Object._C.AbsoluteSize.X, math.max(value, 1));
        elseif property == "PointA" then
            self:__UPDATE_VERTICIES({
                { Object._A, Properties.PointA, Properties.PointB },
                { Object._C, Properties.PointC, Properties.PointA }
            })
        elseif property == "PointB" then
            self:__UPDATE_VERTICIES({
                { Object._A, Properties.PointA, Properties.PointB },
                { Object._B, Properties.PointB, Properties.PointC }
            })
        elseif property == "PointC" then
            self:__UPDATE_VERTICIES({
                { Object._B, Properties.PointB, Properties.PointC },
                { Object._C, Properties.PointC, Properties.PointA }
            })
        elseif property == "Visible" then
            Object.Visible = value
        elseif property == "ZIndex" then
            Object.ZIndex = value
        end
    end

    function Triangle:__iter()
        return next, self.__PROPERTIES
    end

    function Triangle:__tostring()
        return "Drawing"
    end

    function Triangle:__UPDATE_VERTICIES(verticies)
        local thickness = self.__PROPERTIES.Thickness

        for idx, verticy in verticies do
            Drawing.UpdatePosition(verticy[1], verticy[2], verticy[3], thickness)
        end
    end

    function Triangle:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Triangle:Destroy()
        self:Remove()
    end
    --#endregion

    --#region Quad
    local Quad = {}

    Drawing.__CLASSES["Quad"] = Quad

    function Quad.new()
        local QuadObject = setmetatable({
            __OBJECT_EXISTS = true,
            __PROPERTIES = {
                Color = Color3.new(0, 0, 0),
                PointA = Vector2.new(0, 0),
                PointB = Vector2.new(0, 0),
                PointC = Vector2.new(0, 0),
                PointD = Vector2.new(0, 0),
                Thickness = 1,
                Transparency = 1,
                ZIndex = 0,
                Filled = false,
                Visible = false
            },
            __OBJECT = Drawing.CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ZIndex = 0,
                Visible = false,
                Parent = Drawing.__ROOT
            }, {
                Drawing.CreateInstance("Frame", {
                    Name = "_A",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                }),
                Drawing.CreateInstance("Frame", {
                    Name = "_B",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                }),
                Drawing.CreateInstance("Frame", {
                    Name = "_C",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                }),
                Drawing.CreateInstance("Frame", {
                    Name = "_D",
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 0, 0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 0
                })
            })
        }, Quad)

        table.insert(Drawing.__OBJECT_CACHE, QuadObject)

        return QuadObject
    end

    function Quad:__index(property)
        local value = self.__PROPERTIES[property]

        if value ~= nil then
            return value
        end

        return Quad[property]
    end

    function Quad:__newindex(property, value)
        if not self.__OBJECT_EXISTS then
            return error("Attempt to modify drawing that no longer exists!", 2)
        end

        local Properties, Object = self.__PROPERTIES, self.__OBJECT

        Properties[property] = value

        if property == "Color" then
            Object._A.BackgroundColor3 = value
            Object._B.BackgroundColor3 = value
            Object._C.BackgroundColor3 = value
            Object._D.BackgroundColor3 = value
        elseif property == "Transparency" then
            Object._A.BackgroundTransparency = 1 - values
            Object._B.BackgroundTransparency = 1 - values
            Object._C.BackgroundTransparency = 1 - values
            Object._D.BackgroundTransparency = 1 - values
        elseif property == "Thickness" then
            Object._A.BackgroundColor3 = UDim2.fromOffset(Object._A.AbsoluteSize.X, math.max(value, 1));
            Object._B.BackgroundColor3 = UDim2.fromOffset(Object._B.AbsoluteSize.X, math.max(value, 1));
            Object._C.BackgroundColor3 = UDim2.fromOffset(Object._C.AbsoluteSize.X, math.max(value, 1));
            Object._D.BackgroundColor3 = UDim2.fromOffset(Object._D.AbsoluteSize.X, math.max(value, 1));
        elseif property == "PointA" then
            self:__UPDATE_VERTICIES({
                { Object._A, Properties.PointA, Properties.PointB },
                { Object._D, Properties.PointD, Properties.PointA }
            })
        elseif property == "PointB" then
            self:__UPDATE_VERTICIES({
                { Object._A, Properties.PointA, Properties.PointB },
                { Object._B, Properties.PointB, Properties.PointC }
            })
        elseif property == "PointC" then
            self:__UPDATE_VERTICIES({
                { Object._B, Properties.PointB, Properties.PointC },
                { Object._C, Properties.PointC, Properties.PointD }
            })
        elseif property == "PointD" then
            self:__UPDATE_VERTICIES({
                { Object._C, Properties.PointC, Properties.PointD },
                { Object._D, Properties.PointD, Properties.PointA }
            })
        elseif property == "Visible" then
            Object.Visible = value
        elseif property == "ZIndex" then
            Object.ZIndex = value
        end
    end

    function Quad:__iter()
        return next, self.__PROPERTIES
    end

    function Quad:__tostring()
        return "Drawing"
    end

    function Quad:__UPDATE_VERTICIES(verticies)
        local thickness = self.__PROPERTIES.Thickness

        for idx, verticy in verticies do
            Drawing.UpdatePosition(verticy[1], verticy[2], verticy[3], thickness)
        end
    end

    function Quad:Remove()
        self.__OBJECT_EXISTS = false
        self.__OBJECT.Destroy(self.__OBJECT)
        table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
    end

    function Quad:Destroy()
        self:Remove()
    end
    --#endregion

    if not isfolder("DrawingFontCache") then
        makefolder("DrawingFontCache")
    end

    Drawing.Font.new("UI", "rbxasset://fonts/families/Arial.json")
    Drawing.Font.new("System", "rbxasset://fonts/families/HighwayGothic.json")
    Drawing.Font.new("Plex", "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/oADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwBrAG8AcwB3AHsAfwCDAIcAiwCPAAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAgICAgICABICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAABwGAAAACAAQAAAMABwALAA8AEwAXABsAAAE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQM1MxUBgICAgICAgICAgICAgIADgICAgICAgICAgICAgICAgICA/wCAgAAGAQADAAKABIAAAwAHAAsADwATABcAAAE1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQEAgICA/oCAgID+gICAgAQAgICAgICAgICAgICAgIAAABgAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwAAATUzFTM1MxUFNTMVMzUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVMzUzFQU1MxUzNTMVAYCAgID+gICAgP2AgICAgICA/YCAgID+gICAgP2AgICAgICA/YCAgID+gICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAFQCA/4ADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAABNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMTUzFTE1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUBgID/AICAgID9gICAgP6AgICA/wCAgID/AICAgP6AgICA/YCAgICA/wCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAUAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAATNTMVITUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVBzUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVITUzFYCAAYCA/QCAgICAgP2AgICAgID+AICAgICAgID+AICAgICA/YCAgICAgP0AgAGAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTM1MxUBAICA/oCAAQCA/gCAAQCA/oCAgAEAgP0AgAEAgICA/QCAAYCA/YCAAYCA/gCAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAMBgAMAAgAEgAADAAcACwAAATUzFQc1MxUHNTMVAYCAgICAgAQAgICAgICAgIAAAAsBAP8AAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsAAAE1MxUFNTMVBzUzFQU1MxUHNTMVBzUzFQc1MxUHNTMdATUzFQc1Mx0BNTMVAgCA/wCAgID/AICAgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAALAQD/AAKABIAAAwAHAAsADwATABcAGwAfACMAJwArAAABNTMdATUzFQc1Mx0BNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUHNTMVBTUzFQEAgICAgICAgICAgICAgP8AgICA/wCABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAACwCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAAATUzFQU1MxUzNTMVMzUzFQU1MxUxNTMVMTUzFQU1MxUzNTMVMzUzFQU1MxUBgID+gICAgICA/gCAgID+AICAgICA/oCAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgAAACQCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjAAABNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUBgICAgP6AgICAgID+gICAgAKAgICAgICAgICAgICAgICAgICAgICAgAAABACA/wABgAEAAAMABwALAA8AACU1MxUHNTMVBzUzFQU1MxUBAICAgICA/wCAgICAgICAgICAgICAAAAABQCAAYADAAIAAAMABwALAA8AEwAAEzUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgIABgICAgICAgICAgIAAAgEAAAABgAEAAAMABwAAJTUzFQc1MxUBAICAgICAgICAgAAACgCA/4ADAASAAAMABwALAA8AEwAXABsAHwAjACcAAAE1MxUHNTMVBTUzFQc1MxUFNTMVBzUzFQU1MxUHNTMVBTUzFQc1MxUCgICAgP8AgICA/wCAgID/AICAgP8AgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAUAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/YCAgICAgP2AgICAgID9gIABgID9gIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAADgCAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFQU1MxUxNTMVBTUzFTM1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUBgID/AICA/oCAgICAgICAgICAgP6AgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA8AgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwAAATUzFTE1MxUxNTMVBTUzFSE1MxUHNTMVBTUzFQU1MxUFNTMVBTUzFQc1MxUxNTMVMTUzFTE1MxUxNTMVAQCAgID+AIABgICAgP8AgP8AgP8AgP8AgICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAPAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBzUzFQU1MxUxNTMdATUzFQc1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCAgID+gICAgICA/YCAAYCA/gCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEQCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFQU1MxUxNTMVBTUzFTM1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUCgID/AICA/oCAgID+AIABAID9gIABgID9gICAgICAgP8AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUxNTMVMTUzFTE1Mx0BNTMVBzUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVgICAgICA/YCAgICAgICAgICAgP2AgAGAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAARAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAABNTMVMTUzFQU1MxUFNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQGAgID+gID/AICAgICAgP4AgAGAgP2AgAGAgP2AgAGAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADACAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAATNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBzUzFQU1MxUHNTMVBTUzFQc1MxWAgICAgICAgP8AgICA/wCAgID/AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAATAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/gCAgID+AIABgID9gIABgID9gIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEQCAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFTE1MxUBAICAgP4AgAGAgP2AgAGAgP2AgAGAgP4AgICAgICA/wCA/oCAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAQBgAAAAgADAAADAAcACwAPAAABNTMVBzUzFQM1MxUHNTMVAYCAgICAgICAAoCAgICAgP6AgICAgIAAAAYAgP8AAYADAAADAAcACwAPABMAFwAAATUzFQc1MxUDNTMVBzUzFQc1MxUFNTMVAQCAgICAgICAgID/AIACgICAgICA/oCAgICAgICAgICAgAAAAAoAAACAAwADAAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFQU1MxUxNTMVBTUzFTE1Mx0BNTMVMTUzHQE1MxUxNTMVAgCAgP4AgID+AICAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAADACAAQADgAKAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAATNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICA/QCAgICAgIACAICAgICAgICAgICAgP8AgICAgICAgICAgICAAAAKAIAAgAOAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFTE1Mx0BNTMVMTUzHQE1MxUxNTMVBTUzFTE1MxUFNTMVMTUzFYCAgICAgID+AICA/gCAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAoAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFTE1MxUFNTMVITUzFQc1MxUFNTMVBTUzFQc1MxUDNTMVAQCAgID+AIABgICAgP8AgP8AgICAgIADgICAgICAgICAgICAgICAgICAgICAgICA/wCAgAAaAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVMTUzFTM1MxUFNTMVMzUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUhNTMVMTUzFTE1MxUFNTMdATUzFTE1MxUxNTMVMTUzFQEAgICA/gCAAYCA/QCAAQCAgICA/ICAgICAgICA/ICAgICAgICA/ICAAQCAgID9gICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTE1MxUFNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP8AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgP4AgAGAgP2AgAGAgP2AgICAgID9gIACAID9AIACAID9AIACAID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFSE1MxUFNTMVMTUzFTE1MxUBgICAgP4AgAGAgP0AgICAgICAgIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAUAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAgICA/gCAAYCA/YCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAYCA/YCAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAATAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP2AgICAgICAgID+AICAgICAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAPAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAABM1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFYCAgICAgP2AgICAgICAgID+AICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQGAgICA/gCAAYCA/QCAgICAgAEAgICA/QCAAgCA/YCAAYCA/gCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAEzUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxWAgAIAgP0AgAIAgP0AgAIAgP0AgICAgICA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAwBAAAAAoAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAAATUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgID/AICAgICAgICAgICA/wCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAADACAAAACgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAABNTMVMTUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBAICAgICAgICAgICAgICAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAARAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQU1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFYCAAgCA/QCAAYCA/YCAAQCA/gCAgID+gICAgP6AgAEAgP4AgAGAgP2AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAMAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AABM1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgICAgICAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABoAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwBjAGcAABE1MxUxNTMVITUzFTE1MxUFNTMVMTUzFSE1MxUxNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgIABgICA/ICAgAGAgID8gICAgICAgID8gICAgICAgID8gIABAIABAID8gIABAIABAID8gIACgID8gIACgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAYAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AABM1MxUxNTMVITUzFQU1MxUxNTMVITUzFQU1MxUzNTMVITUzFQU1MxUzNTMVITUzFQU1MxUhNTMVMzUzFQU1MxUhNTMVMzUzFQU1MxUhNTMVMTUzFQU1MxUhNTMVMTUzFYCAgAGAgP0AgIABgID9AICAgAEAgP0AgICAAQCA/QCAAQCAgID9AIABAICAgP0AgAGAgID9AIABgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAYCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAARAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFYCAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAgICA/gCAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEgCA/4ADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMzUzFQc1MxUBgICA/oCAAQCA/YCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAAQCA/oCAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAEzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxWAgICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgICAgP4AgAEAgP4AgAGAgP2AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMdATUzFTE1Mx0BNTMVMTUzHQE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBAICAgID9gIACAID9AICAgICAgP0AgAIAgP2AgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAOAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFYCAgICAgID+AICAgICAgICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAABM1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA4AAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAABE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP2AgAGAgP4AgICA/oCAgID/AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAYAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AABE1MxUhNTMVBTUzFSE1MxUhNTMVBTUzFSE1MxUhNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVMTUzFTM1MxUxNTMVBTUzFSE1MxUFNTMVITUzFYACgID8gIABAIABAID8gIABAIABAID8gICAgICAgID8gICAgICAgID9AICAgICA/YCAAYCA/YCAAYCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQU1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgIACAID9AIACAID9gIABAID+gICA/wCAgP6AgAEAgP2AgAIAgP0AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAwAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAAETUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAABM1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFQU1MxUFNTMVBTUzFQc1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgP8AgP8AgP8AgP8AgP8AgICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAADwEA/wACgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AAABNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUBAICAgP6AgICAgICAgICAgICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAoAgP+AAwAEgAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVBzUzHQE1MxUHNTMdATUzFQc1Mx0BNTMVBzUzHQE1MxUHNTMVgICAgICAgICAgICAgICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAA8BAP8AAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwAAATUzFTE1MxUxNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgICAgICAgICAgICAgICAgICAgID+gICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAKAIABgAMABIAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFQc1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQGAgICA/wCAgID+gICAgP4AgAGAgP2AgAGAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAcAAP+AA4AAAAADAAcACwAPABMAFwAbAAAVNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAgICAgICAgICAgICAgICAgAACAQADgAIABIAAAwAHAAABNTMdATUzFQEAgIAEAICAgICAAAAQAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTE1MxUxNTMdATUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAATAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAEzUzFQc1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAMAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAgICAgAGAgP4AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAATAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAATUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQKAgICAgID+AICAgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEACAAAADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFTE1MxUxNTMVBTUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUBgICAgP4AgICA/wCAgICA/oCAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAVAID+gAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQEAgICAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICAgICAgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAABM1MxUHNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgICAgICAgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gIABgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAACAEAAAACAASAAAMABwALAA8AEwAXABsAHwAAATUzFQE1MxUxNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUBgID/AICAgICAgICAgICAgAQAgID+gICAgICAgICAgICAgICAgICAgIAAAAAMAID/AAKABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AAAE1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQIAgP8AgICAgICAgICAgICAgID+AICAgAQAgID+gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAEzUzFQc1MxUHNTMVBzUzFSE1MxUFNTMVITUzFQU1MxUzNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFYCAgICAgICAAYCA/YCAAQCA/gCAgID+gICAgP6AgAEAgP4AgAGAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAKAQAAAAIABIAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQEAgICAgICAgICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFAAAAAADgAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAETUzFTE1MxUxNTMVMzUzFTE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxWAgICAgID9AIABAIABAID8gIABAIABAID8gIABAIABAID8gIABAIABAID8gIABAIABAIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA4AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAABM1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gIABgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA4AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gICAgID+AICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBzUzFQc1MxUHNTMVAQCAgICA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAgICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAoAgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVMzUzFTE1MxUFNTMVMTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMVgICAgID+AICAAQCA/YCAgICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAA0AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVMTUzFTE1MxUxNTMVBTUzHQE1MxUxNTMdATUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVAQCAgICA/YCAgICAgP2AgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA0BAAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFTE1MxUxNTMVAQCAgICAgICAgP4AgICAgICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAKAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFSE1MxUFNTMVITUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVBzUzFYCAAYCA/YCAAYCA/gCAgID+gICAgP8AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAAAAAA4ADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAETUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMzUzFTM1MxUzNTMVBTUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVgAKAgPyAgAEAgAEAgPyAgAEAgAEAgPyAgICAgICAgP0AgICAgID9gIABgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAKAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFSE1MxUFNTMVMzUzFQU1MxUHNTMVBTUzFTM1MxUFNTMVITUzFYCAAYCA/gCAgID/AICAgP8AgICA/gCAAYCAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVgIABgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgICAgICA/gCAgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAOAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICA/wCA/wCA/wCA/wCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAID/AAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAABNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUFNTMVMTUzHQE1MxUHNTMVBzUzFQc1Mx0BNTMVMTUzFQIAgID+gICAgICAgID+gICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAsBgP8AAgAEgAADAAcACwAPABMAFwAbAB8AIwAnACsAAAE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAYCAgICAgICAgICAgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAID/AAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVMTUzHQE1MxUHNTMVBzUzFQc1Mx0BNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFYCAgICAgICAgICAgP6AgICAgICAgP6AgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAgAAAGAA4ACgAADAAcACwAPABMAFwAbAB8AABM1MxUxNTMVMTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVgICAgAEAgPyAgAEAgICAAgCAgICAgICAgICAgICAgICAgAAAABMAgAAAA4ADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAYCAgID+AIABgID9AICAgID+gID/AICAgID+gIABgID+AICAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAABAEA/wACAAEAAAMABwALAA8AACU1MxUHNTMVBzUzFQU1MxUBgICAgICA/wCAgICAgICAgICAgICAAAAAEACA/wADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUxNTMVBTUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUCAICA/oCAgID/AICAgID+gICAgICAgICAgICA/oCAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAYBAP+AAoABAAADAAcACwAPABMAFwAAJTUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVAQCAgID+gICAgP6AgICAgICAgICAgICAgICAgICAAAAAAwCAAAADAACAAAMABwALAAAzNTMVMzUzFTM1MxWAgICAgICAgICAgIAAAAANAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwAAATUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgICA/oCAgICAgP6AgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAAAE1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVAYCAgID+gICAgICA/oCA/oCAgICAgP6AgICAgICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAUAgAMAAwAEgAADAAcACwAPABMAAAE1MxUFNTMVMzUzFQU1MxUhNTMVAYCA/wCAgID+AIABgIAEAICAgICAgICAgICAgAAAAA4AgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUFNTMVITUzFQU1MxUzNTMVBzUzFQU1MxUHNTMVMzUzFTM1MxUFNTMVITUzFTM1MxUFNTMVAgCA/gCAAQCA/gCAgICAgP8AgICAgICAgP0AgAEAgICA/QCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAVAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUzNTMVBTUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1Mx0BNTMVMTUzHQE1MxUxNTMdATUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/wCA/wCAgICA/YCAAgCA/QCAgICAgID9AIACAID9gICAgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAABQCAAIACAAMAAAMABwALAA8AEwAAATUzFQU1MxUFNTMdATUzHQE1MxUBgID/AID/AICAgAKAgICAgICAgICAgICAgIAAAAAAGAAAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAAATNTMVMTUzFTM1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUzNTMVMTUzFTE1MxWAgICAgICA/ICAAQCA/gCAAQCA/gCAAQCAgID9AIABAID+AIABAID+AIABAID+gICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABUAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwAAATUzFTM1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBzUzFQU1MxUFNTMVBTUzFQU1MxUFNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVAQCAgID/AID+gICAgICAgICA/wCA/wCA/wCA/wCA/wCAgICAgICAgASAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAADAYADAAKABIAAAwAHAAsAAAE1MxUHNTMdATUzFQGAgICAgAQAgICAgICAgIAAAAADAQADAAIABIAAAwAHAAsAAAE1MxUHNTMVBTUzFQGAgICA/wCABACAgICAgICAgAAGAQADAAMABIAAAwAHAAsADwATABcAAAE1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQEAgICA/oCAgID/AICAgAQAgICAgICAgICAgICAgIAAAAYAgAMAAoAEgAADAAcACwAPABMAFwAAATUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVAQCAgID+gICAgP4AgICABACAgICAgICAgICAgICAgAAADQCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUFNTMVMTUzFTE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQU1MxUBgID/AICAgP4AgICAgID+AICAgP8AgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAUAgAGAAwACAAADAAcACwAPABMAABM1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAAYCAgICAgICAgICAAAcAAAGAA4ACAAADAAcACwAPABMAFwAbAAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAgAGAgICAgICAgICAgICAgIAAAAAABACAAwACgAQAAAMABwALAA8AAAE1MxUzNTMVBTUzFTM1MxUBAICAgP4AgICAA4CAgICAgICAgIAAAAAAEAAAAgADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AABE1MxUxNTMVMTUzFTM1MxUxNTMVMTUzFQU1MxUhNTMVMTUzFTE1MxUFNTMVITUzFTM1MxUFNTMVITUzFTM1MxWAgICAgICA/QCAAQCAgID9AIABAICAgP0AgAEAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUFNTMVATUzFTE1MxUxNTMVMTUzFQU1Mx0BNTMVMTUzHQE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/wCA/wCAgICA/YCAgICAgP2AgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAFAIAAgAIAAwAAAwAHAAsADwATAAATNTMdATUzHQE1MxUFNTMVBTUzFYCAgID/AID/AIACgICAgICAgICAgICAgICAABUAAAAAA4ADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwAAEzUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVITUzFQU1MxUhNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMTUzFTM1MxUxNTMVgICAgICA/QCAAQCAAQCA/ICAAQCAgICA/ICAAQCA/gCAAQCAAQCA/QCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEQCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTM1MxUFNTMVATUzFTE1MxUxNTMVMTUzFTE1MxUHNTMVBTUzFQU1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUBAICAgP8AgP6AgICAgICAgP8AgP8AgP8AgP8AgICAgIAEAICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADQAAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUzNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUBAICAgP2AgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCAgICAgAQAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAHAYAAAAIABAAAAwAHAAsADwATABcAGwAAATUzFQM1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgICAgICAgICAgICAgAOAgID/AICAgICAgICAgICAgICAgICAABIAgP+AAwADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUxNTMVMTUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVMTUzFTE1MxUFNTMVAYCA/wCAgID+AICAgICA/YCAgID+gICAgP6AgICAgID+AICAgP8AgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTE1MxUFNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQU1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQGAgID+gICAgP8AgICAgP6AgICA/wCAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAUAAAAAAOAA4AAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAARNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFYACgID9AICAgICA/YCAAYCA/YCAAYCA/YCAAYCA/YCAgICAgP0AgAKAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABAAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAARNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCA/oCAgICAgP6AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAACgGA/wACAASAAAMABwALAA8AEwAXABsAHwAjACcAAAE1MxUHNTMVBzUzFQc1MxUHNTMVAzUzFQc1MxUHNTMVBzUzFQc1MxUBgICAgICAgICAgICAgICAgICAgIAEAICAgICAgICAgICAgICA/wCAgICAgICAgICAgICAgAAAAAASAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzHQE1MxUxNTMVBTUzFTM1MxUFNTMVMTUzHQE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAgID/AICAgP8AgICA/YCAAYCA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAACAQAEAAKABIAAAwAHAAABNTMVMzUzFQEAgICABACAgICAAAAcAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAGsAbwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVMTUzFTM1MxUFNTMVMzUzFSE1MxUFNTMVMzUzFSE1MxUFNTMVITUzFTE1MxUzNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP0AgAKAgPyAgAEAgICAgPyAgICAAYCA/ICAgIABgID8gIABAICAgID8gIACgID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAACwCAAYACgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAAATUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgP6AgICA/gCAAQCA/oCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAKAIAAgAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQGAgICA/gCAgID+AICAgP8AgICA/wCAgIACgICAgICAgICAgICAgICAgICAgICAgICAgAAABwCAAAACgAIAAAMABwALAA8AEwAXABsAABM1MxUxNTMVMTUzFTE1MxUHNTMVBzUzFQc1MxWAgICAgICAgICAgAGAgICAgICAgICAgICAgICAgIAAHgAAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwBrAG8AcwB3AAATNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTM1MxUxNTMVITUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVMzUzFTE1MxUhNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgID9AIACgID8gICAgIABAID8gICAgICAgID8gICAgIABAID8gICAgICAgID8gIACgID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAABwAABIADgAUAAAMABwALAA8AEwAXABsAABE1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICABICAgICAgICAgICAgICAgAAAAAAIAIACgAKABIAAAwAHAAsADwATABcAGwAfAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQEAgID+gIABAID+AIABAID+gICABACAgICAgICAgICAgICAgICAgICAAAAAAA4AgAAAAwADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVAYCAgID+gICAgICA/oCAgID+gICAgICAAwCAgICAgICAgICAgICAgICAgICAgICA/wCAgICAgICAgICAAAoAgAIAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVMTUzFTE1Mx0BNTMVBTUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVgICAgID/AID/AID/AICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAACgCAAgACgASAAAMABwALAA8AEwAXABsAHwAjACcAABM1MxUxNTMVMTUzHQE1MxUFNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxWAgICAgP6AgICA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAAAAACAYADgAKABIAAAwAHAAABNTMVBTUzFQIAgP8AgAQAgICAgIAAAAAAEQAA/wADgAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAEzUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFSE1MxUFNTMVMzUzFTE1MxUzNTMVBTUzFQU1MxWAgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgIABAID9gICAgICAgP0AgP8AgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGgCA/4ADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwAAATUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVMTUzFTE1MxUzNTMVBTUzFTE1MxUxNTMVMzUzFQU1MxUxNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUBAICAgICA/QCAgICAgP2AgICAgID+AICAgID+gICAgP6AgICA/oCAgID+gICAgP6AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAJAQABAAKAAoAAAwAHAAsADwATABcAGwAfACMAAAE1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQEAgICA/oCAgID+gICAgAIAgICAgICAgICAgICAgICAgICAgIAAAAQBgP6AAoAAAAADAAcACwAPAAAFNTMVMTUzFQc1MxUFNTMVAYCAgICA/wCAgICAgICAgICAgIAACACAAgACAASAAAMABwALAA8AEwAXABsAHwAAATUzFQU1MxUxNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBAID/AICAgICAgP8AgICABACAgICAgICAgICAgICAgICAgICAgAAAAAoAgAIAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAQCAgP6AgAEAgP4AgAEAgP4AgAEAgP6AgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAKAIAAgAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFYCAgID/AICAgP8AgICA/gCAgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAAAE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQc1MxUFNTMVITUzFQU1MxUzNTMVMTUzFQU1MxUzNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUCgID9gIABgID9gIABAID+AIABAID+AICAgICA/wCAAQCA/gCAgICA/YCAgICAgID9AIABgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABYAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAAABNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUHNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVAoCA/YCAAYCA/YCAAQCA/gCAAQCA/gCAgICAgICA/gCAAYCA/YCAAQCA/YCAAQCA/gCAAQCAgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAaAAAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAAABNTMVBTUzFTE1MxUhNTMVBTUzFTM1MxUFNTMVMTUzFTM1MxUFNTMVMTUzFQU1MxUxNTMVMzUzFQU1MxUhNTMVBTUzFTM1MxUxNTMVBTUzFTM1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQKAgP0AgIABgID+AICAgP4AgICAgP6AgID+AICAgID/AIABAID+AICAgID9gICAgICAgP0AgAGAgASAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAKAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFQM1MxUHNTMVBTUzFQU1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQGAgICAgID/AID/AICAgAGAgP4AgICAA4CAgP8AgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMdATUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBgICA/wCAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUFNTMVAzUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQIAgP8AgICAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABQAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AAAE1MxUxNTMVBTUzFSE1MxUBNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP6AgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTM1MxUFNTMVMzUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBgICAgP4AgICA/wCAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAASAIAAAAOABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQEAgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABYAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP6AgAEAgP4AgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAXAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAAABNTMVMTUzFTE1MxUxNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUhNTMVMTUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUxNTMVMTUzFQGAgICAgP2AgICA/oCAgID+AIABAICA/YCAgICA/YCAAYCA/YCAAYCA/YCAAYCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEQCA/oADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFSE1MxUFNTMVMTUzFTE1MxUFNTMVBzUzFQU1MxUBgICAgP4AgAGAgP0AgICAgICAgIABgID+AICAgP8AgICA/wCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAUAIAAAAMABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMdATUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQEAgID+gICAgICA/YCAgICAgICAgP4AgICAgICAgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAUAIAAAAMABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVBTUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQIAgP8AgP6AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFQCAAAADAAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUBgID/AICAgP4AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAFACAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTM1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUBAICAgP4AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADQEAAAACgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1Mx0BNTMVATUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBgICA/oCAgID/AICAgICAgICAgP8AgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgAANAQAAAAKABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwAAATUzFQU1MxUBNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQIAgP8AgP8AgICA/wCAgICAgICAgID/AICAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAOAQAAAAKABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQGAgP8AgICA/oCAgID/AICAgICAgICAgP8AgICABICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA0BAAAAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVMzUzFQE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgID+gICAgP8AgICAgICAgICA/wCAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAFQAAAAADgAOAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxWAgICAgP4AgAGAgP2AgAIAgPyAgICAgAEAgP0AgAIAgP0AgAGAgP2AgICAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABkAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwBjAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUxNTMVBTUzFSE1MxUxNTMVAYCAgID+AICAgP4AgIABgID9AICAgAEAgP0AgICAAQCA/QCAAQCAgID9AIABAICAgP0AgAGAgID9AIABgICABICAgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABAAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMdATUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAYCAgP8AgID+gIABAID9gIACAID9AIACAID9AIACAID9gIABAID+gICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFQU1MxUDNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQIAgP8AgICAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFQU1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBgICA/oCAAQCA/oCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBgICAgP4AgICA/wCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEACAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBAIABAID+gICA/oCAAQCA/YCAAgCA/QCAAgCA/QCAAgCA/YCAAQCA/oCAgAQAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAkAgACAAwADAAADAAcACwAPABMAFwAbAB8AIwAAEzUzFSE1MxUFNTMVMzUzFQU1MxUFNTMVMzUzFQU1MxUhNTMVgIABgID+AICAgP8AgP8AgICA/gCAAYCAAoCAgICAgICAgICAgICAgICAgICAgICAAAAAFgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAAAE1MxUxNTMVMzUzFQU1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUzNTMVBTUzFTM1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFTE1MxUBgICAgID9gIABAID9gIABAICAgP0AgAEAgICA/QCAgIABAID9AICAgAEAgP2AgAEAgP2AgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP4AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgICAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAgCA/wCA/oCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABQAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AAAE1MxUxNTMVBTUzFSE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgICAgASAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVITUzFQE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBAIABAID9gIACAID9AIACAID9AIACAID9AIACAID9AIACAID9AIACAID9gICAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADQAAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUFNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUCAID/AID+AIACgID8gIACgID9AIABgID+AICAgP8AgICAgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAEzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFYCAgICAgICAgP4AgAGAgP2AgAGAgP2AgICAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGQAA/4ADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUBAICAgP4AgAGAgP2AgAGAgP2AgICAgP4AgAGAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgICAgID9AIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVMTUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP6AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVBTUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUCAID/AID/AICAgID+AICAgID9gIABgID9gIABgID+AICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEwCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsAAAE1MxUFNTMVMzUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBgID/AICAgP6AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAUAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMdATUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgICA/gCAgID+gICAgID+AICAgID9gIABgID9gIABgID+AICAgIAEAICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTM1MxUBNTMVMTUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAQCAgID+gICAgID+AICAgID9gIABgID9gIABgID+AICAgIADgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAFACAAAADAAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFQU1MxUzNTMVBTUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBgID/AICAgP8AgP8AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgASAgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAWAAAAAAOAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwAAEzUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP6AgAEAgP0AgICAgICA/ICAAQCA/gCAAQCAAQCA/QCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAPAID+gAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQU1MxUHNTMVBTUzFQEAgICA/gCAAYCA/YCAgICAgAGAgP4AgICA/wCAgID/AIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgP8AgICA/gCAAYCA/YCAgICAgP2AgICAAYCA/gCAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUDNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABMAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgID+gICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgID+gICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICAA4CAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAkBAAAAAgAEgAADAAcACwAPABMAFwAbAB8AIwAAATUzHQE1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAQCAgP8AgICAgICAgICAgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgAAJAQAAAAIABIAAAwAHAAsADwATABcAGwAfACMAAAE1MxUFNTMVAzUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgP8AgICAgICAgICAgICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAAAAAAAoBAAAAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVBTUzFTM1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAYCA/wCAgID+gICAgICAgICAgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgAAJAQAAAAKABIAAAwAHAAsADwATABcAGwAfACMAAAE1MxUzNTMVATUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQEAgICA/oCAgICAgICAgICAgIAEAICAgID+gICAgICAgICAgICAgICAgICAgIAAFACAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTE1MxUzNTMVBTUzFQU1MxUzNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgID/AID/AICAgICA/gCAgICA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBAICAgP4AgICA/oCAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCABACAgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzHQE1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgID/AICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMVBTUzFQE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAgCA/wCA/wCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAAAE1MxUFNTMVMzUzFQE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgID+gICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBgICAgP4AgICA/oCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAQAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/oCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAOAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAcAgACAAwADAAADAAcACwAPABMAFwAbAAABNTMVATUzFTE1MxUxNTMVMTUzFTE1MxUBNTMVAYCA/oCAgICAgP6AgAKAgID/AICAgICAgICAgID/AICAAAAUAID/gAMAA4AAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUxNTMVBTUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVBTUzFTE1MxUhNTMVBTUzFTE1MxUxNTMVBTUzFQKAgP4AgICA/gCAAQCAgP2AgICAgID9gICAgICA/YCAgAEAgP4AgICA/gCAAwCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzHQE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgID+gIABgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFQU1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgP8AgP8AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAARAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAABNTMVBTUzFTM1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgP8AgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAA4CAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAVAID+gAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUFNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1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MDAxMA51bmljb2RlIzB4MDAxMQ51bmljb2RlIzB4MDAxMg51bmljb2RlIzB4MDAxMw51bmljb2RlIzB4MDAxNA51bmljb2RlIzB4MDAxNQ51bmljb2RlIzB4MDAxNg51bmljb2RlIzB4MDAxNw51bmljb2RlIzB4MDAxOA51bmljb2RlIzB4MDAxOQ51bmljb2RlIzB4MDAxYQ51bmljb2RlIzB4MDAxYg51bmljb2RlIzB4MDAxYw51bmljb2RlIzB4MDAxZA51bmljb2RlIzB4MDAxZQ51bmljb2RlIzB4MDAxZgZkZWxldGUERXVybw51bmljb2RlIzB4MDA4MQ51bmljb2RlIzB4MDA4Mg51bmljb2RlIzB4MDA4Mw51bmljb2RlIzB4MDA4NA51bmljb2RlIzB4MDA4NQ51bmljb2RlIzB4MDA4Ng51bmljb2RlIzB4MDA4Nw51bmljb2RlIzB4MDA4OA51bmljb2RlIzB4MDA4OQ51bmljb2RlIzB4MDA4YQ51bmljb2RlIzB4MDA4Yg51bmljb2RlIzB4MDA4Yw51bmljb2RlIzB4MDA4ZA51bmljb2RlIzB4MDA4ZQ51bmljb2RlIzB4MDA4Zg51bmljb2RlIzB4MDA5MA51bmljb2RlIzB4MDA5MQ51bmljb2RlIzB4MDA5Mg51bmljb2RlIzB4MDA5Mw51bmljb2RlIzB4MDA5NA51bmljb2RlIzB4MDA5NQ51bmljb2RlIzB4MDA5Ng51bmljb2RlIzB4MDA5Nw51bmljb2RlIzB4MDA5OA51bmljb2RlIzB4MDA5OQ51bmljb2RlIzB4MDA5YQ51bmljb2RlIzB4MDA5Yg51bmljb2RlIzB4MDA5Yw51bmljb2RlIzB4MDA5ZA51bmljb2RlIzB4MDA5ZQ51bmljb2RlIzB4MDA5ZgAA")
    Drawing.Font.new("Monospace", "rbxasset://fonts/families/RobotoMono.json")
    Drawing.Font.new("Pixel", "AAEAAAAMAIAAAwBAT1MvMmSz/H0AAAFIAAAAYFZETVhoYG/3AAAGmAAABeBjbWFwel+AIwAADHgAAAUwZ2FzcP//AAEAAGP4AAAACGdseWa90hIhAAARqAAARRRoZWFk/hqSzwAAAMwAAAA2aGhlYQegBbsAAAEEAAAAJGhtdHhmdgAAAAABqAAABPBsb2Nh73HeDAAAVrwAAAJ6bWF4cAFBADMAAAEoAAAAIG5hbWX/R4pVAABZOAAABC1wb3N0fPqooAAAXWgAAAaOAAEAAAABAAArGZw2Xw889QAJA+gAAAAAzSamLgAAAADNJqljAAD/OASwAyAAAAAJAAIAAAAAAAAAAQAAAu7/BgAABRQAAABkBLAAAQAAAAAAAAAAAAAAAAAAATwAAQAAATwAMgAEAAAAAAABAAAAAAAAAAAAAAAAAAAAAAADAfMBkAAFAAACvAKKAAD/nAK8AooAAAD6ADIA+gAAAgAAAAAAAAAAAIAAAi8AAAAKAAAAAAAAAABQWVJTAEAAICEiAu7/BgAAAyAAyAAAAAUAAAAAAPoB9AAAACAAAAH0AAAAAAAAAfQAAAH0AAACWAAAAlgAAAJYAAAAyAAAAS0AAAEtAAABkAAAAZAAAAEsAAABkAAAAMgAAAJYAAAB9AAAAZAAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAMgAAAEsAAABkAAAAZAAAAGQAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAZAAAAH0AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAGQAAACWAAAAfQAAAGQAAAB9AAAASwAAAJYAAABLAAAAlgAAAH0AAABLAAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAZAAAAJYAAAB9AAAAZAAAAH0AAABkAAAAMgAAAGQAAAB9AAAAlgAAAH0AAABLAAAAfQAAAJYAAACWAAAAZAAAAGQAAACWAAAAyAAAAJYAAABkAAAAlgAAAH0AAACWAAAAZAAAAJYAAABLAAAASwAAAJYAAACWAAAASwAAAGQAAAB9AAAA4QAAAJYAAABkAAAAlgAAAH0AAACWAAAAZAAAAGQAAABkAAAAfQAAAH0AAAB9AAAAMgAAAH0AAAB9AAAAyAAAAH0AAACvAAAAfQAAAEsAAADIAAAAZAAAAGQAAABkAAAAZAAAAGQAAAB9AAAAlgAAAJYAAAAyAAAAfQAAAK8AAAB9AAAArwAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAfQAAAH0AAAB9AAAAlgAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAJYAAAB9AAAAlgAAAH0AAACWAAAArwAAAJYAAACvAAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAlgAAAH0AAACWAAAAfQAAAJYAAACvAAAAlgAAAK8AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAAyAAAAlgAAAH0AAABkAAAAZAAAAH0AAAB9AAAAfQAAAEsAAABkAAAAZAAAAH0AAAFFAAABRQAAAUUAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAZAAAAGQAAABkAAAAZAAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAlgAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAZAAAAGQAAABkAAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAACWAAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAZAAAAJYAAACWAAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAZAAAAH0AAACWAAAAMgAAAGQAAAAAAABAAEBAQEBAAwA+Aj/AAgAB//+AAkACP/+AAoACP/+AAsACf/9AAwACv/9AA0AC//9AA4ADP/9AA8ADP/9ABAADf/8ABEADv/8ABIAD//8ABMAEP/8ABQAEP/8ABUAEf/7ABYAEv/7ABcAE//7ABgAFP/7ABkAFP/7ABoAFf/6ABsAFv/6ABwAF//6AB0AGP/6AB4AGP/6AB8AGf/5ACAAGv/5ACEAG//5ACIAHP/5ACMAHP/5ACQAHf/4ACUAHv/4ACYAH//4ACcAIP/4ACgAIP/4ACkAIf/3ACoAIv/3ACsAI//3ACwAJP/3AC0AJP/3AC4AJf/2AC8AJv/2ADAAJ//2ADEAKP/2ADIAKP/2ADMAKf/1ADQAKv/1ADUAK//1ADYALP/1ADcALP/1ADgALf/0ADkALv/0ADoAL//0ADsAMP/0ADwAMP/0AD0AMf/zAD4AMv/zAD8AM//zAEAANP/zAEEANP/zAEIANf/yAEMANv/yAEQAN//yAEUAOP/yAEYAOP/yAEcAOf/xAEgAOv/xAEkAO//xAEoAPP/xAEsAPP/xAEwAPf/wAE0APv/wAE4AP//wAE8AQP/wAFAAQP/wAFEAQf/vAFIAQv/vAFMAQ//vAFQARP/vAFUARP/vAFYARf/uAFcARv/uAFgAR//uAFkASP/uAFoASP/uAFsASf/tAFwASv/tAF0AS//tAF4ATP/tAF8ATP/tAGAATf/sAGEATv/sAGIAT//sAGMAUP/sAGQAUP/sAGUAUf/rAGYAUv/rAGcAU//rAGgAVP/rAGkAVP/rAGoAVf/qAGsAVv/qAGwAV//qAG0AWP/qAG4AWP/qAG8AWf/pAHAAWv/pAHEAW//pAHIAXP/pAHMAXP/pAHQAXf/oAHUAXv/oAHYAX//oAHcAYP/oAHgAYP/oAHkAYf/nAHoAYv/nAHsAY//nAHwAZP/nAH0AZP/nAH4AZf/mAH8AZv/mAIAAZ//mAIEAaP/mAIIAaP/mAIMAaf/lAIQAav/lAIUAa//lAIYAbP/lAIcAbP/lAIgAbf/kAIkAbv/kAIoAb//kAIsAcP/kAIwAcP/kAI0Acf/jAI4Acv/jAI8Ac//jAJAAdP/jAJEAdP/jAJIAdf/iAJMAdv/iAJQAd//iAJUAeP/iAJYAeP/iAJcAef/hAJgAev/hAJkAe//hAJoAfP/hAJsAfP/hAJwAff/gAJ0Afv/gAJ4Af//gAJ8AgP/gAKAAgP/gAKEAgf/fAKIAgv/fAKMAg//fAKQAhP/fAKUAhP/fAKYAhf/eAKcAhv/eAKgAh//eAKkAiP/eAKoAiP/eAKsAif/dAKwAiv/dAK0Ai//d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ATkBOgE7ATwBPQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgBSQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFcAV0BXgFfAWABYQFiAWMBZAFlAWYAowCEAIUAlgCOAJ0A8gDzAI0A3gDxAJ4A9QD0APYAogCtAMkAxwCuAGIAYwCQAGQAywBlAMgAygDPAMwAzQDOAOkAZgDTANAA0QCvAGcA8ACRANYA1ADVAGgA6wDtAIkAagBpAGsAbQBsAG4AoABvAHEAcAByAHMAdQB0AHYAdwDqAHgAegB5AHsAfQB8ALgAoQB/AH4AgACBAOwA7gC6ALAAsQDkAOUAuwDmAOcApgDYANkABgAEAAUFLm51bGwJYWZpaTEwMDUxCWFmaWkxMDA1MglhZmlpMTAxMDAERXVybwlhZmlpMTAwNTgJYWZpaTEwMDU5CWFmaWkxMDA2MQlhZmlpMTAwNjAJYWZpaTEwMTQ1CWFmaWkxMDA5OQlhZmlpMTAxMDYJYWZpaTEwMTA3CWFmaWkxMDEwOQlhZmlpMTAxMDgJYWZpaTEwMTkzCWFmaWkxMDA2MglhZmlpMTAxMTAJYWZpaTEwMDU3CWFmaWkxMDA1MAlhZmlpMTAwMjMJYWZpaTEwMDUzB3VuaTAwQUQJYWZpaTEwMDU2CWFmaWkxMDA1NQlhZmlpMTAxMDMJYWZpaTEwMDk4DnBlcmlvZGNlbnRlcmVkCWFmaWkxMDA3MQlhZmlpNjEzNTIJYWZpaTEwMTAxCWFmaWkxMDEwNQlhZmlpMTAwNTQJYWZpaTEwMTAyCWFmaWkxMDEwNAlhZmlpMTAwMTcJYWZpaTEwMDE4CWFmaWkxMDAxOQlhZmlpMTAwMjAJYWZpaTEwMDIxCWFmaWkxMDAyMglhZmlpMTAwMjQJYWZpaTEwMDI1CWFmaWkxMDAyNglhZmlpMTAwMjcJYWZpaTEwMDI4CWFmaWkxMDAyOQlhZmlpMTAwMzAJYWZpaTEwMDMxCWFmaWkxMDAzMglhZmlpMTAwMzMJYWZpaTEwMDM0CWFmaWkxMDAzNQlhZmlpMTAwMzYJYWZpaTEwMDM3CWFmaWkxMDAzOAlhZmlpMTAwMzkJYWZpaTEwMDQwCWFmaWkxMDA0MQlhZmlpMTAwNDIJYWZpaTEwMDQzCWFmaWkxMDA0NAlhZmlpMTAwNDUJYWZpaTEwMDQ2CWFmaWkxMDA0NwlhZmlpMTAwNDgJYWZpaTEwMDQ5CWFmaWkxMDA2NQlhZmlpMTAwNjYJYWZpaTEwMDY3CWFmaWkxMDA2OAlhZmlpMTAwNjkJYWZpaTEwMDcwCWFmaWkxMDA3MglhZmlpMTAwNzMJYWZpaTEwMDc0CWFmaWkxMDA3NQlhZmlpMTAwNzYJYWZpaTEwMDc3CWFmaWkxMDA3OAlhZmlpMTAwNzkJYWZpaTEwMDgwCWFmaWkxMDA4MQlhZmlpMTAwODIJYWZpaTEwMDgzCWFmaWkxMDA4NAlhZmlpMTAwODUJYWZpaTEwMDg2CWFmaWkxMDA4NwlhZmlpMTAwODgJYWZpaTEwMDg5CWFmaWkxMDA5MAlhZmlpMTAwOTEJYWZpaTEwMDkyCWFmaWkxMDA5MwlhZmlpMTAwOTQJYWZpaTEwMDk1CWFmaWkxMDA5NglhZmlpMTAwOTcNYWZpaTEwMDQ1LjAwMQ1hZmlpMTAwNDcuMDAxAAAAAAAB//8AAA==")

    env.Drawing = Drawing
    env.cleardrawcache = Drawing.ClearCache

end)()


  
local old; old = hookfunction(Drawing.new, function(class, properties)
    local drawing = old(class)
    for i,v in next, properties or {} do
        drawing[i] = v
    end
    return drawing
end)

local HttpService = game:GetService('HttpService')
local Lighting = game:GetService('Lighting')
local runservice = game:GetService('RunService')
local inputservice = game:GetService('UserInputService')
local tweenservice = game:GetService('TweenService')
local camera = workspace.CurrentCamera




-- // make multiselect in order
-- // add border pixel math to dragging
-- // containers canvasscroll update on setvisible
-- // Dragging sys has errors
-- // I think something was wrong with the keybinds/indicators tweening
-- // Menu Effects (OnHover, OnClick)


local Settings = {
    Accent = Color3.fromHex("#00A3E0"),
    Font = Enum.Font.SourceSans,
    IsBackgroundTransparent = true,
    Rounded = false,
    Dim = false,
    
    ItemColor = Color3.fromRGB(30, 30, 30),
    BorderColor = Color3.fromRGB(45, 45, 45),
    MinSize = Vector2.new(450, 450),
    MaxSize = Vector2.new(700, 550)
}


local Menu = {}
local Tabs = {}
local Items = {}
local EventObjects = {} -- For updating items on menu property change
local Notifications = {}

local Scaling = {True = false, Origin = nil, Size = nil}
local Dragging = {Gui = nil, True = false}
local Draggables = {}
local ToolTip = {Enabled = false, Content = "", Item = nil}

local HotkeyRemoveKey = Enum.KeyCode.RightControl
local Selected = {
    Frame = nil,
    Item = nil,
    Offset = UDim2.new(),
    Follow = false
}
local SelectedTab
local SelectedTabLines = {}


local wait = task.wait
local delay = task.delay
local spawn = task.spawn

local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")


local __Menu = {}
setmetatable(Menu, {
    __index = function(self, Key) return __Menu[Key] end,
    __newindex = function(self, Key, Value)
        __Menu[Key] = Value
        
        if Key == "Hue" or Key == "ScreenSize" then return end

        for _, Object in pairs(EventObjects) do Object:Update() end
        for _, Notification in pairs(Notifications) do Notification:Update() end
    end
})


Menu.Accent = Settings.Accent
Menu.Font = Settings.Font
Menu.IsBackgroundTransparent = Settings.IsBackgroundTransparent
Menu.Rounded = Settings.IsRounded
Menu.Dim = Settings.IsDim
Menu.ItemColor = Settings.ItemColor
Menu.BorderColor = Settings.BorderColor
Menu.MinSize = Settings.MinSize
Menu.MaxSize = Settings.MaxSize

Menu.Hue = 0
Menu.IsVisible = false
Menu.ScreenSize = Vector2.new()


local function AddEventListener(self: GuiObject, Update: any)
    table.insert(EventObjects, {
        self = self,
        Update = Update
    })
end


local function CreateCorner(Parent: Instance, Pixels: number): UICorner
    local UICorner = Instance.new("UICorner")
    UICorner.Name = "Corner"
    UICorner.Parent = Parent
    return UICorner
end


local function CreateStroke(Parent: Instance, Color: Color3, Thickness: number, Transparency: number): UIStroke
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Name = "Stroke"
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
    UIStroke.Color = Color or Color3.new()
    UIStroke.Thickness = Thickness or 1
    UIStroke.Transparency = Transparency or 0
    UIStroke.Enabled = true
    UIStroke.Parent = Parent
    return UIStroke
end 


local function CreateLine(Parent: Instance, Size: UDim2, Position: UDim2, Color: Color3): Frame
    local Line = Instance.new("Frame")
    Line.Name = "Line"
    Line.BackgroundColor3 = typeof(Color) == "Color3" and Color or Menu.Accent
    Line.BorderSizePixel = 0
    Line.Size = Size or UDim2.new(1, 0, 0, 1)
    Line.Position = Position or UDim2.new()
    Line.Parent = Parent

    if Line.BackgroundColor3 == Menu.Accent then
        AddEventListener(Line, function() Line.BackgroundColor3 = Menu.Accent end)
    end

    return Line
end


local function CreateLabel(Parent: Instance, Name: string, Text: string, Size: UDim2, Position: UDim2): TextLabel
    local Label = Instance.new("TextLabel")
    Label.Name = Name
    Label.BackgroundTransparency = 1
    Label.Size = Size or UDim2.new(1, 0, 0, 15)
    Label.Position = Position or UDim2.new()
    Label.Font = Enum.Font.SourceSans
    Label.Text = Text or ""
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Parent
    return Label
end


local function UpdateSelected(Frame: Instance, Item: Item, Offset: UDim2)
    local Selected_Frame = Selected.Frame
    if Selected_Frame then
        Selected_Frame.Visible = false
        Selected_Frame.Parent = nil
    end

    Selected = {}

    if Frame then
        if Selected_Frame == Frame then return end
        Selected = {
            Frame = Frame,
            Item = Item,
            Offset = Offset
        }

        Frame.ZIndex = 3
        Frame.Visible = true
        Frame.Parent = Menu.Screen
    end
end


local function SetDraggable(self: GuiObject)
    table.insert(Draggables, self)
    local DragOrigin
    local GuiOrigin

    self.InputBegan:Connect(function(Input: InputObject, Process: boolean)
        if (not Dragging.Gui and not Dragging.True) and (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            for _, v in ipairs(Draggables) do
                v.ZIndex = 1
            end
            self.ZIndex = 2

            Dragging = {Gui = self, True = true}
            DragOrigin = Vector2.new(Input.Position.X, Input.Position.Y)
            GuiOrigin = self.Position
        end
    end)

    UserInput.InputChanged:Connect(function(Input: InputObject, Process: boolean)
        if Dragging.Gui ~= self then return end
        if not (UserInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
            Dragging = {Gui = nil, True = false}
            return
        end
        if (Input.UserInputType == Enum.UserInputType.MouseMovement) then
            local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - DragOrigin
            local ScreenSize = Menu.ScreenSize

            local ScaleX = (ScreenSize.X * GuiOrigin.X.Scale)
            local ScaleY = (ScreenSize.Y * GuiOrigin.Y.Scale)
            local OffsetX = math.clamp(GuiOrigin.X.Offset + Delta.X + ScaleX,   0, ScreenSize.X - self.AbsoluteSize.X)
            local OffsetY = math.clamp(GuiOrigin.Y.Offset + Delta.Y + ScaleY, -36, ScreenSize.Y - self.AbsoluteSize.Y)
            
            local Position = UDim2.fromOffset(OffsetX, OffsetY)
			self.Position = Position
        end
    end)
end


Menu.Screen = Instance.new("ScreenGui")
Menu.Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Menu.ScreenSize = Menu.Screen.AbsoluteSize

local Menu_Frame = Instance.new("Frame")
local MenuScaler_Button = Instance.new("TextButton")
local Title_Label = Instance.new("TextLabel")
local Icon_Image = Instance.new("ImageLabel")
local TabHandler_Frame = Instance.new("Frame")
local TabIndex_Frame = Instance.new("Frame")
local Tabs_Frame = Instance.new("Frame")

local Notifications_Frame = Instance.new("Frame")
local MenuDim_Frame = Instance.new("Frame")
local ToolTip_Label = Instance.new("TextLabel")
local Modal = Instance.new("TextButton")

Menu_Frame.Name = "Menu"
Menu_Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Menu_Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
Menu_Frame.BorderMode = Enum.BorderMode.Inset
Menu_Frame.Position = UDim2.new(0.5, -250, 0.5, -275)
Menu_Frame.Size = UDim2.new(0, 500, 0, 550)
Menu_Frame.Visible = false
Menu_Frame.Parent = Menu.Screen
CreateStroke(Menu_Frame, Color3.new(), 2)
CreateLine(Menu_Frame, UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, 0, 15))
SetDraggable(Menu_Frame)

MenuScaler_Button.Name = "MenuScaler"
MenuScaler_Button.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MenuScaler_Button.BorderColor3 = Color3.fromRGB(40, 40, 40)
MenuScaler_Button.BorderSizePixel = 0
MenuScaler_Button.Position = UDim2.new(1, -15, 1, -15)
MenuScaler_Button.Size = UDim2.fromOffset(15, 15)
MenuScaler_Button.Font = Enum.Font.SourceSans
MenuScaler_Button.Text = ""
MenuScaler_Button.TextColor3 = Color3.new(1, 1, 1)
MenuScaler_Button.TextSize = 14
MenuScaler_Button.AutoButtonColor = false
MenuScaler_Button.Parent = Menu_Frame
MenuScaler_Button.InputBegan:Connect(function(Input, Process)
    if Process then return end
    if (Input.UserInputType == Enum.UserInputType.MouseButton1) then
        UpdateSelected()
        Scaling = {
            True = true,
            Origin = Vector2.new(Input.Position.X, Input.Position.Y),
            Size = Menu_Frame.AbsoluteSize - Vector2.new(0, 36)
        }
    end
end)
MenuScaler_Button.InputEnded:Connect(function(Input, Process)
    if (Input.UserInputType == Enum.UserInputType.MouseButton1) then
        UpdateSelected()
        Scaling = {
            True = false,
            Origin = nil,
            Size = nil
        }
    end
end)

Icon_Image.Name = "Icon"
Icon_Image.BackgroundTransparency = 1
Icon_Image.Position = UDim2.new(0, 5, 0, 0)
Icon_Image.Size = UDim2.fromOffset(15, 15)
Icon_Image.Image = "rbxassetid://0"
Icon_Image.Visible = false
Icon_Image.Parent = Menu_Frame

Title_Label.Name = "Title"
Title_Label.BackgroundTransparency = 1
Title_Label.Position = UDim2.new(0, 5, 0, 0)
Title_Label.Size = UDim2.new(1, -10, 0, 15)
Title_Label.Font = Enum.Font.SourceSans
Title_Label.Text = ""
Title_Label.TextColor3 = Color3.new(1, 1, 1)
Title_Label.TextSize = 14
Title_Label.TextXAlignment = Enum.TextXAlignment.Left
Title_Label.RichText = true
Title_Label.Parent = Menu_Frame

TabHandler_Frame.Name = "TabHandler"
TabHandler_Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TabHandler_Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
TabHandler_Frame.BorderMode = Enum.BorderMode.Inset
TabHandler_Frame.Position = UDim2.new(0, 4, 0, 19)
TabHandler_Frame.Size = UDim2.new(1, -8, 1, -25)
TabHandler_Frame.Parent = Menu_Frame
CreateStroke(TabHandler_Frame, Color3.new(), 2)

TabIndex_Frame.Name = "TabIndex"
TabIndex_Frame.BackgroundTransparency = 1
TabIndex_Frame.Position = UDim2.new(0, 1, 0, 1)
TabIndex_Frame.Size = UDim2.new(1, -2, 0, 20)
TabIndex_Frame.Parent = TabHandler_Frame

Tabs_Frame.Name = "Tabs"
Tabs_Frame.BackgroundTransparency = 1
Tabs_Frame.Position = UDim2.new(0, 1, 0, 26)
Tabs_Frame.Size = UDim2.new(1, -2, 1, -25)
Tabs_Frame.Parent = TabHandler_Frame

Notifications_Frame.Name = "Notifications"
Notifications_Frame.BackgroundTransparency = 1
Notifications_Frame.Size = UDim2.new(1, 0, 1, 36)
Notifications_Frame.Position = UDim2.fromOffset(0, -36)
Notifications_Frame.ZIndex = 5
Notifications_Frame.Parent = Menu.Screen

ToolTip_Label.Name = "ToolTip"
ToolTip_Label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToolTip_Label.BorderColor3 = Menu.BorderColor
ToolTip_Label.BorderMode = Enum.BorderMode.Inset
ToolTip_Label.AutomaticSize = Enum.AutomaticSize.XY
ToolTip_Label.Size = UDim2.fromOffset(0, 0, 0, 15)
ToolTip_Label.Text = ""
ToolTip_Label.TextSize = 14
ToolTip_Label.Font = Enum.Font.SourceSans
ToolTip_Label.TextColor3 = Color3.new(1, 1, 1)
ToolTip_Label.ZIndex = 5
ToolTip_Label.Visible = false
ToolTip_Label.Parent = Menu.Screen
CreateStroke(ToolTip_Label, Color3.new(), 1)
AddEventListener(ToolTip_Label, function()
    ToolTip_Label.BorderColor3 = Menu.BorderColor
end)

Modal.Name = "Modal"
Modal.BackgroundTransparency = 1
Modal.Modal = true
Modal.Text = ""
Modal.Parent = Menu_Frame


--SelectedTabLines.Top = CreateLine(nil, UDim2.new(1, 0, 0, 1), UDim2.new())
SelectedTabLines.Left = CreateLine(nil, UDim2.new(0, 1, 1, 0), UDim2.new(), Color3.new())
SelectedTabLines.Right = CreateLine(nil, UDim2.new(0, 1, 1, 0), UDim2.new(1, -1, 0, 0), Color3.new())
SelectedTabLines.Bottom = CreateLine(TabIndex_Frame, UDim2.new(), UDim2.new(0, 0, 1, 0), Color3.new())
SelectedTabLines.Bottom2 = CreateLine(TabIndex_Frame, UDim2.new(), UDim2.new(), Color3.new())


local function GetDictionaryLength(Dictionary: table)
    local Length = 0
    for _ in pairs(Dictionary) do
        Length += 1
    end
    return Length
end


local function UpdateSelectedTabLines(Tab: Tab)
    if not Tab then return end

    if (Tab.Button.AbsolutePosition.X > Tab.self.AbsolutePosition.X) then
        SelectedTabLines.Left.Visible = true
    else
        SelectedTabLines.Left.Visible = false
    end

    if (Tab.Button.AbsolutePosition.X + Tab.Button.AbsoluteSize.X < Tab.self.AbsolutePosition.X + Tab.self.AbsoluteSize.X) then
        SelectedTabLines.Right.Visible = true
    else
        SelectedTabLines.Right.Visible = false
    end

    --SelectedTabLines.Top.Parent = Tab.Button
    SelectedTabLines.Left.Parent = Tab.Button
    SelectedTabLines.Right.Parent = Tab.Button

    local FRAME_POSITION = Tab.self.AbsolutePosition
    local BUTTON_POSITION = Tab.Button.AbsolutePosition
    local BUTTON_SIZE = Tab.Button.AbsoluteSize
    local LENGTH = BUTTON_POSITION.X - FRAME_POSITION.X
    local OFFSET = (BUTTON_POSITION.X + BUTTON_SIZE.X) - FRAME_POSITION.X

    SelectedTabLines.Bottom.Size = UDim2.new(0, LENGTH + 1, 0, 1)
    SelectedTabLines.Bottom2.Size = UDim2.new(1, -OFFSET, 0, 1)
    SelectedTabLines.Bottom2.Position = UDim2.new(0, OFFSET, 1, 0)
end


local function UpdateTabs()
    for _, Tab in pairs(Tabs) do
        Tab.Button.Size = UDim2.new(1 / GetDictionaryLength(Tabs), 0, 1, 0)
        Tab.Button.Position = UDim2.new((1 / GetDictionaryLength(Tabs)) * (Tab.Index - 1), 0, 0, 0)
    end
    UpdateSelectedTabLines(SelectedTab)
end


local function GetTab(Tab_Name: string): Tab
    assert(Tab_Name, "NO TAB_NAME GIVEN")
    return Tabs[Tab_Name]
end

local function ChangeTab(Tab_Name: string)
    assert(Tabs[Tab_Name], "Tab \"" .. tostring(Tab_Name) .. "\" does not exist!")
    for _, Tab in pairs(Tabs) do
        Tab.self.Visible = false
        Tab.Button.BackgroundColor3 = Menu.ItemColor
        Tab.Button.TextColor3 = Color3.fromRGB(205, 205, 205)
    end
    local Tab = GetTab(Tab_Name)
    Tab.self.Visible = true
    Tab.Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Tab.Button.TextColor3 = Color3.new(1, 1, 1)

    SelectedTab = Tab
    UpdateSelected()
    UpdateSelectedTabLines(Tab)
end


local function GetContainer(Tab_Name: string, Container_Name: string): Container
    assert(Tab_Name, "NO TAB_NAME GIVEN")
    assert(Container_Name, "NO CONTAINER NAME GIVEN")
    return GetTab(Tab_Name)[Container_Name]
end


local function CheckItemIndex(Item_Index: number, Method: string)
    assert(typeof(Item_Index) == "number", "invalid argument #1 to '" .. Method .. "' (number expected, got " .. typeof(Item_Index) .. ")")
    assert(Item_Index <= #Items and Item_Index > 0, "invalid argument #1 to '" .. Method .. "' (index out of range")
end


function Menu:GetItem(Index: number): Item
    CheckItemIndex(Index, "GetItem")
    return Items[Index]
end


function Menu:FindItem(Tab_Name: string, Container_Name: string, Class_Name: string, Name: string): Item
    local Result
    for Index, Item in ipairs(Items) do
        if Item.Tab == Tab_Name and Item.Container == Container_Name then
            if Item.Name == Name and (Item.Class == Class_Name) then
                Result = Index
                break
            end
        end
    end

    if Result then
        return Menu:GetItem(Result)
    else
        return error("Item " .. tostring(Name) .. " was not found")
    end
end


function Menu:SetTitle(Name: string)
    Title_Label.Text = tostring(Name)
end


function Menu:SetIcon(Icon: string)
    if typeof(Icon) == "string" or typeof(Icon) == "number" then
        Title_Label.Position = UDim2.fromOffset(20, 0)
        Title_Label.Size = UDim2.new(1, -40, 0, 15)
        Icon_Image.Image = "rbxassetid://" .. string.gsub(tostring(Icon), "rbxassetid://", "")
        Icon_Image.Visible = true
    else
        Title_Label.Position = UDim2.fromOffset(5, 0)
        Title_Label.Size = UDim2.new(1, -10, 0, 15)
        Icon_Image.Image = ""
        Icon_Image.Visible = false
    end
end


function Menu:SetSize(Size: Vector2)
    local Size = typeof(Size) == "Vector2" and Size or typeof(Size) == "UDim2" and Vector2.new(Size.X, Size.Y) or Menu.MinSize
    local X = Size.X
    local Y = Size.Y

    if (X > Menu.MinSize.X and X < Menu.MaxSize.X) then
        X = math.clamp(X, Menu.MinSize.X, Menu.MaxSize.X)
    end
    if (Y > Menu.MinSize.Y and Y < Menu.MaxSize.Y) then
        Y = math.clamp(Y, Menu.MinSize.Y, Menu.MaxSize.Y)
    end

    Menu_Frame.Size = UDim2.fromOffset(X, Y)
    UpdateTabs()
end


function Menu:SetVisible(Visible: boolean)
    local IsVisible = typeof(Visible) == "boolean" and Visible
    Menu_Frame.Visible = IsVisible
    Menu.IsVisible = IsVisible
    if IsVisible == false then
        UpdateSelected()
    end
end


function Menu:SetTab(Tab_Name: string)
    ChangeTab(Tab_Name)
end


-- this function should be private
function Menu:SetToolTip(Enabled: boolean, Content: string, Item: Instance)
    ToolTip = {
        Enabled = Enabled,
        Content = Content,
        Item = Item
    }

    ToolTip_Label.Visible = Enabled
end


function Menu.Line(Parent: Instance, Size: UDim2, Position: UDim2): Line
    local Line = {self = CreateLine(Parent, Size, Position)}
    Line.Class = "Line"
    return Line
end


function Menu.Tab(Tab_Name: string): Tab
    assert(Tab_Name and typeof(Tab_Name) == "string", "TAB_NAME REQUIRED")
    if Tabs[Tab_Name] then return error("TAB_NAME '" .. tostring(Tab_Name) .. "' ALREADY EXISTS") end
    local Frame = Instance.new("Frame")
    local Button = Instance.new("TextButton")

    local Tab = {self = Frame, Button = Button}
    Tab.Class = "Tab"
    Tab.Index = GetDictionaryLength(Tabs) + 1


    local function CreateSide(Side: string)
        local Frame = Instance.new("ScrollingFrame")
        local ListLayout = Instance.new("UIListLayout")

        Frame.Name = Side
        Frame.Active = true
        Frame.BackgroundTransparency = 1
        Frame.BorderSizePixel = 0
        Frame.Size = Side == "Middle" and UDim2.new(1, -10, 1, -10) or UDim2.new(0.5, -10, 1, -10)
        Frame.Position = (Side == "Left" and UDim2.fromOffset(5, 5)) or (Side == "Right" and UDim2.new(0.5, 5, 0, 5) or Side == "Middle" and UDim2.fromOffset(5, 5))
        Frame.CanvasSize = UDim2.new(0, 0, 0, -10)
        Frame.ScrollBarThickness = 2
        Frame.ScrollBarImageColor3 = Menu.Accent
        Frame.Parent = Tab.self
        AddEventListener(Frame, function()
            Frame.ScrollBarImageColor3 = Menu.Accent
        end)
        Frame:GetPropertyChangedSignal("CanvasPosition"):Connect(UpdateSelected)

        ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Padding = UDim.new(0, 10)
        ListLayout.Parent = Frame
    end


    Button.Name = "Button"
    Button.BackgroundColor3 = Menu.ItemColor
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.SourceSans
    Button.Text = Tab_Name
    Button.TextColor3 = Color3.fromRGB(205, 205, 205)
    Button.TextSize = 14
    Button.Parent = TabIndex_Frame
    AddEventListener(Button, function()
        if Button.TextColor3 == Color3.fromRGB(205, 205, 205) then
            Button.BackgroundColor3 = Menu.ItemColor
        end
        Button.BackgroundColor3 = Menu.ItemColor
        Button.BorderColor3 = Menu.BorderColor
    end)
    Button.MouseButton1Click:Connect(function()
        ChangeTab(Tab_Name)
    end)
    
    Frame.Name = Tab_Name .. "Tab"
    Frame.BackgroundTransparency = 1
    Frame.Size = UDim2.new(1, 0, 1, 0)
    Frame.Visible = false
    Frame.Parent = Tabs_Frame

    CreateSide("Middle")
    CreateSide("Left")
    CreateSide("Right")

    Tabs[Tab_Name] = Tab

    ChangeTab(Tab_Name)
    UpdateTabs()
    return Tab
end


function Menu.Container(Tab_Name: string, Container_Name: string, Side: string): Container
    local Tab = GetTab(Tab_Name)
    assert(typeof(Tab_Name) == "string", "TAB_NAME REQUIRED")
    if Tab[Container_Name] then return error("CONTAINER_NAME '" .. tostring(Container_Name) .. "' ALREADY EXISTS") end
    local Side = Side or "Left"

    local Frame = Instance.new("Frame")
    local Label = CreateLabel(Frame, "Title", Container_Name, UDim2.fromOffset(206, 15),  UDim2.fromOffset(5, 0))
    local Line = CreateLine(Frame, UDim2.new(1, -10, 0, 1), UDim2.fromOffset(5, 15))

    local Container = {self = Frame, Height = 0}
    Container.Class = "Container"
    Container.Visible = true

    function Container:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function Container:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if self.Visible == Visible then return end
        
        Frame.Visible = Visible
        self.Visible = Visible
        self:UpdateSize(Visible and 25 or -25, Frame)
    end

    function Container:UpdateSize(Height: float, Item: GuiObject)
        self.Height += Height
        Frame.Size += UDim2.fromOffset(0, Height)
        Tab.self[Side].CanvasSize += UDim2.fromOffset(0, Height)

        if Item then
            local ItemY = Item.AbsolutePosition.Y
            if math.sign(Height) == 1 then
                ItemY -= 1
            end

            for _, item in ipairs(Frame:GetChildren()) do
                if (item == Label or item == Line or item == Stroke or Item == item) then continue end -- exlude these
                local item_y = item.AbsolutePosition.Y
                if item_y > ItemY then
                    item.Position += UDim2.fromOffset(0, Height)
                end
            end
        end
    end

    function Container:GetHeight(): number
        return self.Height
    end


    Frame.Name = "Container"
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderColor3 = Color3.new()
    Frame.BorderMode = Enum.BorderMode.Inset
    Frame.Size = UDim2.new(1, -6, 0, 0)
    Frame.Parent = Tab.self[Side]

    Container:UpdateSize(25)
    Tab.self[Side].CanvasSize += UDim2.fromOffset(0, 10)
    Tab[Container_Name] = Container
    return Container
end


function Menu.Label(Tab_Name: string, Container_Name: string, Name: string, ToolTip: string): Label
    local Container = GetContainer(Tab_Name, Container_Name)
    local GuiLabel = CreateLabel(Container.self, "Label", Name, nil, UDim2.fromOffset(20, Container:GetHeight()))

    GuiLabel.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, GuiLabel)
        end
    end)
    GuiLabel.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    local Label = {self = Label}
    Label.Name = Name
    Label.Class = "Label"
    Label.Index = #Items + 1
    Label.Tab = Tab_Name
    Label.Container = Container_Name

    function Label:SetLabel(Name: string)
        GuiLabel.Text = tostring(Name)
    end

    function Label:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if GuiLabel.Visible == Visible then return end
        
        GuiLabel.Visible = Visible
        Container:UpdateSize(Visible and 20 or -20, GuiLabel)
    end

    Container:UpdateSize(20)
    table.insert(Items, Label)
    return #Items
end


function Menu.Button(Tab_Name: string, Container_Name: string, Name: string, Callback: any, ToolTip: string): Button
    local Container = GetContainer(Tab_Name, Container_Name)
    local GuiButton = Instance.new("TextButton")

    local Button = {self = GuiButton}
    Button.Name = Name
    Button.Class = "Button"
    Button.Tab = Tab_Name
    Button.Container = Container_Name
    Button.Index = #Items + 1
    Button.Callback = typeof(Callback) == "function" and Callback or function() end

    
    function Button:SetLabel(Name: string)
        GuiButton.Text = tostring(Name)
    end

    function Button:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if GuiButton.Visible == Visible then return end
        
        GuiButton.Visible = Visible
        Container:UpdateSize(Visible and 25 or -25, GuiButton)
    end


    GuiButton.Name = "Button"
    GuiButton.BackgroundColor3 = Menu.ItemColor
    GuiButton.BorderColor3 = Menu.BorderColor
    GuiButton.BorderMode = Enum.BorderMode.Inset
    GuiButton.Position = UDim2.fromOffset(20, Container:GetHeight())
    GuiButton.Size = UDim2.new(1, -50, 0, 20)
    GuiButton.Font = Enum.Font.SourceSansSemibold
    GuiButton.Text = Name
    GuiButton.TextColor3 = Color3.new(1, 1, 1)
    GuiButton.TextSize = 14
    GuiButton.TextTruncate = Enum.TextTruncate.AtEnd
    GuiButton.Parent = Container.self
    CreateStroke(GuiButton, Color3.new(), 1)
    AddEventListener(GuiButton, function()
        GuiButton.BackgroundColor3 = Menu.ItemColor
        GuiButton.BorderColor3 = Menu.BorderColor
    end)
    GuiButton.MouseButton1Click:Connect(function()
        Button.Callback()
    end)
    GuiButton.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, GuiButton)
        end
    end)
    GuiButton.MouseLeave:Connect(function()
        Menu:SetToolTip(false)
    end)

    Container:UpdateSize(25)
    table.insert(Items, Button)
    return #Items
end


function Menu.TextBox(Tab_Name: string, Container_Name: string, Name: string, Value: string, Callback: any, ToolTip: string): TextBox
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "TextBox", Name, nil, UDim2.fromOffset(20, Container:GetHeight()))
    local GuiTextBox = Instance.new("TextBox")

    local TextBox = {self = GuiTextBox}
    TextBox.Name = Name
    TextBox.Class = "TextBox"
    TextBox.Tab = Tab_Name
    TextBox.Container = Container_Name
    TextBox.Index = #Items + 1
    TextBox.Value = typeof(Value) == "string" and Value or ""
    TextBox.Callback = typeof(Callback) == "function" and Callback or function() end


    function TextBox:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function TextBox:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 45 or -45, Label)
    end

    function TextBox:GetValue(): string
        return self.Value
    end

    function TextBox:SetValue(Value: string)
        self.Value = tostring(Value)
        GuiTextBox.Text = self.Value
    end


    GuiTextBox.Name = "TextBox"
    GuiTextBox.BackgroundColor3 = Menu.ItemColor
    GuiTextBox.BorderColor3 = Menu.BorderColor
    GuiTextBox.BorderMode = Enum.BorderMode.Inset
    GuiTextBox.Position = UDim2.fromOffset(0, 20)
    GuiTextBox.Size = UDim2.new(1, -50, 0, 20)
    GuiTextBox.Font = Enum.Font.SourceSansSemibold
    GuiTextBox.Text = TextBox.Value
    GuiTextBox.TextColor3 = Color3.new(1, 1, 1)
    GuiTextBox.TextSize = 14
    GuiTextBox.ClearTextOnFocus = false
    GuiTextBox.ClipsDescendants = true
    GuiTextBox.Parent = Label
    CreateStroke(GuiTextBox, Color3.new(), 1)
    AddEventListener(GuiTextBox, function()
        GuiTextBox.BackgroundColor3 = Menu.ItemColor
        GuiTextBox.BorderColor3 = Menu.BorderColor
    end)
    GuiTextBox.FocusLost:Connect(function()
        TextBox.Value = GuiTextBox.Text
        TextBox.Callback(GuiTextBox.Text)
    end)
    GuiTextBox.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, GuiTextBox)
        end
    end)
    GuiTextBox.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Container:UpdateSize(45)
    table.insert(Items, TextBox)
    return #Items
end


function Menu.CheckBox(Tab_Name: string, Container_Name: string, Name: string, Boolean: boolean, Callback: any, ToolTip: string): CheckBox
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "CheckBox", Name, nil, UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    
    local CheckBox = {self = Label}
    CheckBox.Name = Name
    CheckBox.Class = "CheckBox"
    CheckBox.Tab = Tab_Name
    CheckBox.Container = Container_Name
    CheckBox.Index = #Items + 1
    CheckBox.Value = typeof(Boolean) == "boolean" and Boolean or false
    CheckBox.Callback = typeof(Callback) == "function" and Callback or function() end


    function CheckBox:Update(Value: boolean)
        self.Value = typeof(Value) == "boolean" and Value
        Button.BackgroundColor3 = self.Value and Menu.Accent or Menu.ItemColor
    end

    function CheckBox:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function CheckBox:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 20 or -20, Label)
    end

    function CheckBox:GetValue(): boolean
        return self.Value
    end

    function CheckBox:SetValue(Value: boolean)
        self:Update(Value)
    end


    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Button.BackgroundColor3 = Menu.ItemColor
    Button.BorderColor3 = Color3.new()
    Button.Position = UDim2.fromOffset(-14, 4)
    Button.Size = UDim2.fromOffset(8, 8)
    Button.Text = ""
    Button.Parent = Label
    AddEventListener(Button, function()
        Button.BackgroundColor3 = CheckBox.Value and Menu.Accent or Menu.ItemColor
    end)
    Button.MouseButton1Click:Connect(function()
        CheckBox:Update(not CheckBox.Value)
        CheckBox.Callback(CheckBox.Value)
    end)

    CheckBox:Update(CheckBox.Value)
    Container:UpdateSize(20)
    table.insert(Items, CheckBox)
    return #Items
end


function Menu.Hotkey(Tab_Name: string, Container_Name: string, Name: string, Key:EnumItem, Callback: any, ToolTip: string): Hotkey
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "Hotkey", Name, nil, UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    local Selected_Hotkey = Instance.new("Frame")
    local HotkeyToggle = Instance.new("TextButton")
    local HotkeyHold = Instance.new("TextButton")

    local Hotkey = {self = Label}
    Hotkey.Name = Name
    Hotkey.Class = "Hotkey"
    Hotkey.Tab = Tab_Name
    Hotkey.Container = Container_Name
    Hotkey.Index = #Items + 1
    Hotkey.Key = typeof(Key) == "EnumItem" and Key or nil
    Hotkey.Callback = typeof(Callback) == "function" and Callback or function() end
    Hotkey.Editing = false
    Hotkey.Mode = "Toggle"


    function Hotkey:Update(Input: EnumItem, Mode: string)
        Button.Text = Input and string.format("[%s]", Input.Name) or "[None]"

        self.Key = Input
        self.Mode = Mode or "Toggle"
        self.Editing = false
    end

    function Hotkey:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function Hotkey:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 20 or -20, Label)
    end

    function Hotkey:GetValue(): EnumItem--, string
        return self.Key, self.Mode
    end

    function Hotkey:SetValue(Key: EnumItem, Mode: string)
        self:Update(Key, Mode)
    end


    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Button.Name = "Hotkey"
    Button.BackgroundTransparency = 1
    Button.Position = UDim2.new(1, -100, 0, 4)
    Button.Size = UDim2.fromOffset(75, 8)
    Button.Font = Enum.Font.SourceSans
    Button.Text = Key and "[" .. Key.Name .. "]" or "[None]"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.TextXAlignment = Enum.TextXAlignment.Right
    Button.Parent = Label

    Selected_Hotkey.Name = "Selected_Hotkey"
    Selected_Hotkey.Visible = false
    Selected_Hotkey.BackgroundColor3 = Menu.ItemColor
    Selected_Hotkey.BorderColor3 = Menu.BorderColor
    Selected_Hotkey.Position = UDim2.fromOffset(200, 100)
    Selected_Hotkey.Size = UDim2.fromOffset(100, 30)
    Selected_Hotkey.Parent = nil
    CreateStroke(Selected_Hotkey, Color3.new(), 1)
    AddEventListener(Selected_Hotkey, function()
        Selected_Hotkey.BackgroundColor3 = Menu.ItemColor
        Selected_Hotkey.BorderColor3 = Menu.BorderColor
    end)

    HotkeyToggle.Parent = Selected_Hotkey
    HotkeyToggle.BackgroundColor3 = Menu.ItemColor
    HotkeyToggle.BorderColor3 = Color3.new()
    HotkeyToggle.BorderSizePixel = 0
    HotkeyToggle.Position = UDim2.new()
    HotkeyToggle.Size = UDim2.new(1, 0, 0, 13)
    HotkeyToggle.Font = Enum.Font.SourceSans
    HotkeyToggle.Text = "Toggle"
    HotkeyToggle.TextColor3 = Menu.Accent
    HotkeyToggle.TextSize = 14
    AddEventListener(HotkeyToggle, function()
        HotkeyToggle.BackgroundColor3 = Menu.ItemColor
        if Hotkey.Mode == "Toggle" then
            HotkeyToggle.TextColor3 = Menu.Accent
        end
    end)
    HotkeyToggle.MouseButton1Click:Connect(function()
        Hotkey:Update(Hotkey.Key, "Toggle")
        HotkeyToggle.TextColor3 = Menu.Accent
        HotkeyHold.TextColor3 = Color3.new(1, 1, 1)
        UpdateSelected()
        Hotkey.Callback(Hotkey.Key, Hotkey.Mode)
    end)

    HotkeyHold.Parent = Selected_Hotkey
    HotkeyHold.BackgroundColor3 = Menu.ItemColor
    HotkeyHold.BorderColor3 = Color3.new()
    HotkeyHold.BorderSizePixel = 0
    HotkeyHold.Position = UDim2.new(0, 0, 0, 15)
    HotkeyHold.Size = UDim2.new(1, 0, 0, 13)
    HotkeyHold.Font = Enum.Font.SourceSans
    HotkeyHold.Text = "Hold"
    HotkeyHold.TextColor3 = Color3.new(1, 1, 1)
    HotkeyHold.TextSize = 14
    AddEventListener(HotkeyHold, function()
        HotkeyHold.BackgroundColor3 = Menu.ItemColor
        if Hotkey.Mode == "Hold" then
            HotkeyHold.TextColor3 = Menu.Accent
        end
    end)
    HotkeyHold.MouseButton1Click:Connect(function()
        Hotkey:Update(Hotkey.Key, "Hold")
        HotkeyHold.TextColor3 = Menu.Accent
        HotkeyToggle.TextColor3 = Color3.new(1, 1, 1)
        UpdateSelected()
        Hotkey.Callback(Hotkey.Key, Hotkey.Mode)
    end)

    Button.MouseButton1Click:Connect(function()
        Button.Text = "..."
        Hotkey.Editing = true
        if UserInput:IsKeyDown(HotkeyRemoveKey) and Key ~= HotkeyRemoveKey then
            Hotkey:Update()
            Hotkey.Callback(nil, Hotkey.Mode)
        end
    end)
    Button.MouseButton2Click:Connect(function()
        UpdateSelected(Selected_Hotkey, Button, UDim2.fromOffset(100, 0))
    end)

    UserInput.InputBegan:Connect(function(Input)
        if Hotkey.Editing then
            local Key = Input.KeyCode
            if Key == Enum.KeyCode.Unknown then
                local InputType = Input.UserInputType
                Hotkey:Update(InputType)
                Hotkey.Callback(InputType, Hotkey.Mode)
            else
                Hotkey:Update(Key)
                Hotkey.Callback(Key, Hotkey.Mode)
            end
        end
    end)

    Container:UpdateSize(20)
    table.insert(Items, Hotkey)
    return #Items
end


function Menu.Slider(Tab_Name: string, Container_Name: string, Name: string, Min: number, Max: number, Value: number, Unit: string, Scale: number, Callback: any, ToolTip: string): Slider
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "Slider", Name, UDim2.new(1, -10, 0, 15), UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    local ValueBar = Instance.new("TextLabel")
    local ValueBox = Instance.new("TextBox")
    local ValueLabel = Instance.new("TextLabel")

    local Slider = {}
    Slider.Name = Name
    Slider.Class = "Slider"
    Slider.Tab = Tab_Name
    Slider.Container = Container_Name
    Slider.Index = #Items + 1
    Slider.Min = typeof(Min) == "number" and math.clamp(Min, Min, Max) or 0
    Slider.Max = typeof(Max) == "number" and Max or 100
    Slider.Value = typeof(Value) == "number" and Value or 100
    Slider.Unit = typeof(Unit) == "string" and Unit or ""
    Slider.Scale = typeof(Scale) == "number" and Scale or 0
    Slider.Callback = typeof(Callback) == "function" and Callback or function() end


    local function UpdateSlider(Percentage: number)
        local Percentage = typeof(Percentage == "number") and math.clamp(Percentage, 0, 1) or 0
        local Value = Slider.Min + ((Slider.Max - Slider.Min) * Percentage)
        local Scale = (10 ^ Slider.Scale)
        Slider.Value = math.round(Value * Scale) / Scale

        ValueBar.Size = UDim2.new(Percentage, 0, 0, 5)
        ValueBox.Text = "[" .. Slider.Value .. "]"
        ValueLabel.Text = Slider.Value .. Slider.Unit
    end


    function Slider:Update(Percentage: number)
        UpdateSlider(Percentage)
    end

    function Slider:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function Slider:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 30 or -30, Label)
    end

    function Slider:GetValue(): number
        return self.Value
    end

    function Slider:SetValue(Value: number)
        self.Value = typeof(Value) == "number" and math.clamp(Value, self.Min, self.Max) or self.Min
        local Percentage = (self.Value - self.Min) / (self.Max - self.Min)
        self:Update(Percentage)
    end

    Slider.self = Label

    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        Menu:SetToolTip(false)
    end)

    Button.Name = "Slider"
    Button.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Button.BorderColor3 = Color3.new()
    Button.Position = UDim2.fromOffset(0, 20)
    Button.Size = UDim2.new(1, -40, 0, 5)
    Button.Text = ""
    Button.AutoButtonColor = false
    Button.Parent = Label

    ValueBar.Name = "ValueBar"
    ValueBar.BackgroundColor3 = Menu.Accent
    ValueBar.BorderSizePixel = 0
    ValueBar.Size = UDim2.fromScale(1, 1)
    ValueBar.Text = ""
    ValueBar.Parent = Button
    AddEventListener(ValueBar, function()
        ValueBar.BackgroundColor3 = Menu.Accent
    end)
    
    ValueBox.Name = "ValueBox"
    ValueBox.BackgroundTransparency = 1
    ValueBox.Position = UDim2.new(1, -65, 0, 5)
    ValueBox.Size = UDim2.fromOffset(50, 10)
    ValueBox.Font = Enum.Font.SourceSans
    ValueBox.Text = ""
    ValueBox.TextColor3 = Color3.new(1, 1, 1)
    ValueBox.TextSize = 12
    ValueBox.TextXAlignment = Enum.TextXAlignment.Right
    ValueBox.ClipsDescendants = true
    ValueBox.Parent = Label
    ValueBox.FocusLost:Connect(function()
        Slider.Value = tonumber(ValueBox.Text) or 0
        local Percentage = (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
        Slider:Update(Percentage)
        Slider.Callback(Slider.Value)
    end)

    ValueLabel.Name = "ValueLabel"
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Position = UDim2.new(1, 0, 0, 2)
    ValueLabel.Size = UDim2.new(0, 0, 1, 0)
    ValueLabel.Font = Enum.Font.SourceSansBold
    ValueLabel.Text = ""
    ValueLabel.TextColor3 = Color3.new(1, 1, 1)
    ValueLabel.TextSize = 14
    ValueLabel.Parent = ValueBar

    Button.InputBegan:Connect(function(Input: InputObject, Process: boolean)
        if (not Dragging.Gui and not Dragging.True) and (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            Dragging = {Gui = Button, True = true}
            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local Percentage = (InputPosition - Button.AbsolutePosition) / Button.AbsoluteSize
            Slider:Update(Percentage.X)
            Slider.Callback(Slider.Value)
        end
    end)

    UserInput.InputChanged:Connect(function(Input: InputObject, Process: boolean)
        if Dragging.Gui ~= Button then return end
        if not (UserInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
            Dragging = {Gui = nil, True = false}
            return
        end
        if (Input.UserInputType == Enum.UserInputType.MouseMovement) then
            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local Percentage = (InputPosition - Button.AbsolutePosition) / Button.AbsoluteSize
            Slider:Update(Percentage.X)
            Slider.Callback(Slider.Value)
        end
    end)


    Slider:SetValue(Slider.Value)
    Container:UpdateSize(30)
    table.insert(Items, Slider)
    return #Items
end


function Menu.ColorPicker(Tab_Name: string, Container_Name: string, Name: string, Color: Color3, Alpha: number, Callback: any, ToolTip: string): ColorPicker
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "ColorPicker", Name, UDim2.new(1, -10, 0, 15), UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    local Selected_ColorPicker = Instance.new("Frame")
    local HexBox = Instance.new("TextBox")
    local Saturation = Instance.new("ImageButton")
    local Alpha = Instance.new("ImageButton")
    local Hue = Instance.new("ImageButton")
    local SaturationCursor = Instance.new("Frame")
    local AlphaCursor = Instance.new("Frame")
    local HueCursor = Instance.new("Frame")
    local CopyButton = Instance.new("TextButton") -- rbxassetid://9090721920
    local PasteButton = Instance.new("TextButton") -- rbxassetid://9090721063
    local AlphaColorGradient = Instance.new("UIGradient")

    local ColorPicker = {self = Label}
    ColorPicker.Name = Name
    ColorPicker.Tab = Tab_Name
    ColorPicker.Class = "ColorPicker"
    ColorPicker.Container = Container_Name
    ColorPicker.Index = #Items + 1
    ColorPicker.Color = typeof(Color) == "Color3" and Color or Color3.new(1, 1, 1)
    ColorPicker.Saturation = {0, 0} -- no i'm not going to use ColorPicker.Value that would confuse people with ColorPicker.Color
    ColorPicker.Alpha = typeof(Alpha) == "number" and Alpha or 0
    ColorPicker.Hue = 0
    ColorPicker.Callback = typeof(Callback) == "function" and Callback or function() end


    local function UpdateColor()
        ColorPicker.Color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Saturation[1], ColorPicker.Saturation[2])

        HexBox.Text = "#" .. string.upper(ColorPicker.Color:ToHex()) .. string.upper(string.format("%X", ColorPicker.Alpha * 255))
        Button.BackgroundColor3 = ColorPicker.Color
        Saturation.BackgroundColor3 = ColorPicker.Color
        AlphaColorGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, ColorPicker.Color)}

        SaturationCursor.Position = UDim2.fromScale(math.clamp(ColorPicker.Saturation[1], 0, 0.95), math.clamp(1 - ColorPicker.Saturation[2], 0, 0.95))
        AlphaCursor.Position = UDim2.fromScale(0, math.clamp(ColorPicker.Alpha, 0, 0.98))
        HueCursor.Position = UDim2.fromScale(0, math.clamp(ColorPicker.Hue, 0, 0.98))

        ColorPicker.Callback(ColorPicker.Color, ColorPicker.Alpha)
    end


    function ColorPicker:Update()
        UpdateColor()
    end

    function ColorPicker:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function ColorPicker:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 20 or -20, Label)
    end

    function ColorPicker:SetValue(Color: Color3, Alpha: number)
        self.Color, self.Alpha = typeof(Color) == "Color3" and Color or Color3.new(), typeof(Alpha) == "number" and Alpha or 0
        self.Hue, self.Saturation[1], self.Saturation[2] = self.Color:ToHSV()
        self:Update()
    end

    function ColorPicker:GetValue(): Color3--, number
        return self.Color, self.Alpha
    end


    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Button.Name = "ColorPicker"
    Button.BackgroundColor3 = ColorPicker.Color
    Button.BorderColor3 = Color3.new()
    Button.Position = UDim2.new(1, -35, 0, 4)
    Button.Size = UDim2.fromOffset(20, 8)
    Button.Font = Enum.Font.SourceSans
    Button.Text = ""
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Parent = Label
    Button.MouseButton1Click:Connect(function()
        UpdateSelected(Selected_ColorPicker, Button, UDim2.fromOffset(20, 20))
    end)

    Selected_ColorPicker.Name = "Selected_ColorPicker"
    Selected_ColorPicker.Visible = false
    Selected_ColorPicker.BackgroundColor3 = Menu.ItemColor
    Selected_ColorPicker.BorderColor3 = Menu.BorderColor
    Selected_ColorPicker.BorderMode = Enum.BorderMode.Inset
    Selected_ColorPicker.Position = UDim2.new(0, 200, 0, 170)
    Selected_ColorPicker.Size = UDim2.new(0, 190, 0, 180)
    Selected_ColorPicker.Parent = nil
    CreateStroke(Selected_ColorPicker, Color3.new(), 1)
    AddEventListener(Selected_ColorPicker, function()
        Selected_ColorPicker.BackgroundColor3 = Menu.ItemColor
        Selected_ColorPicker.BorderColor3 = Menu.BorderColor
    end)

    HexBox.Name = "Hex"
    HexBox.BackgroundColor3 = Menu.ItemColor
    HexBox.BorderColor3 = Menu.BorderColor
    HexBox.BorderMode = Enum.BorderMode.Inset
    HexBox.Size = UDim2.new(1, -10, 0, 20)
    HexBox.Position = UDim2.fromOffset(5, 150)
    HexBox.Text = "#" .. string.upper(ColorPicker.Color:ToHex())
    HexBox.Font = Enum.Font.SourceSansSemibold
    HexBox.TextSize = 14
    HexBox.TextColor3 = Color3.new(1, 1, 1)
    HexBox.ClearTextOnFocus = false
    HexBox.ClipsDescendants = true
    HexBox.Parent = Selected_ColorPicker
    CreateStroke(HexBox, Color3.new(), 1)
    HexBox.FocusLost:Connect(function()
        pcall(function()
            local Color, Alpha = string.sub(HexBox.Text, 1, 7), string.sub(HexBox.Text, 8, #HexBox.Text)
            ColorPicker.Color = Color3.fromHex(Color)
            ColorPicker.Alpha = tonumber(Alpha, 16) / 255
            ColorPicker.Hue, ColorPicker.Saturation[1], ColorPicker.Saturation[2] = ColorPicker.Color:ToHSV()
            ColorPicker:Update()
        end)
    end)
    AddEventListener(HexBox, function()
        HexBox.BackgroundColor3 = Menu.ItemColor
        HexBox.BorderColor3 = Menu.BorderColor
    end)

    Saturation.Name = "Saturation"
    Saturation.BackgroundColor3 = ColorPicker.Color
    Saturation.BorderColor3 = Menu.BorderColor
    Saturation.Position = UDim2.new(0, 4, 0, 4)
    Saturation.Size = UDim2.new(0, 150, 0, 140)
    Saturation.Image = "rbxassetid://8180999986"
    Saturation.ImageColor3 = Color3.new()
    Saturation.AutoButtonColor = false
    Saturation.Parent = Selected_ColorPicker
    CreateStroke(Saturation, Color3.new(), 1)
    AddEventListener(Saturation, function()
        Saturation.BorderColor3 = Menu.BorderColor
    end)
    
    Alpha.Name = "Alpha"
    Alpha.BorderColor3 = Menu.BorderColor
    Alpha.Position = UDim2.new(0, 175, 0, 4)
    Alpha.Size = UDim2.new(0, 10, 0, 140)
    Alpha.Image = "rbxassetid://9090739505"--"rbxassetid://8181003956"
    Alpha.ScaleType = Enum.ScaleType.Crop
    Alpha.AutoButtonColor = false
    Alpha.Parent = Selected_ColorPicker
    CreateStroke(Alpha, Color3.new(), 1)
    AddEventListener(Alpha, function()
        Alpha.BorderColor3 = Menu.BorderColor
    end)

    Hue.Name = "Hue"
    Hue.BackgroundColor3 = Color3.new(1, 1, 1)
    Hue.BorderColor3 = Menu.BorderColor
    Hue.Position = UDim2.new(0, 160, 0, 4)
    Hue.Size = UDim2.new(0, 10, 0, 140)
    Hue.Image = "rbxassetid://8180989234"
    Hue.ScaleType = Enum.ScaleType.Crop
    Hue.AutoButtonColor = false
    Hue.Parent = Selected_ColorPicker
    CreateStroke(Hue, Color3.new(), 1)
    AddEventListener(Hue, function()
        Hue.BorderColor3 = Menu.BorderColor
    end)

    SaturationCursor.Name = "Cursor"
    SaturationCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    SaturationCursor.BorderColor3 = Color3.new()
    SaturationCursor.Size = UDim2.fromOffset(5, 5)
    SaturationCursor.Parent = Saturation

    AlphaCursor.Name = "Cursor"
    AlphaCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    AlphaCursor.BorderColor3 = Color3.new()
    AlphaCursor.Size = UDim2.new(1, 0, 0, 2)
    AlphaCursor.Parent = Alpha

    HueCursor.Name = "Cursor"
    HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    HueCursor.BorderColor3 = Color3.new()
    HueCursor.Size = UDim2.new(1, 0, 0, 2)
    HueCursor.Parent = Hue

    AlphaColorGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, ColorPicker.Color)}
    AlphaColorGradient.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.20), NumberSequenceKeypoint.new(1, 0.2)}
    AlphaColorGradient.Offset = Vector2.new(0, -0.1)
    AlphaColorGradient.Rotation = -90
    AlphaColorGradient.Parent = Alpha

    local function UpdateSaturation(PercentageX: number, PercentageY: number)
        local PercentageX = typeof(PercentageX == "number") and math.clamp(PercentageX, 0, 1) or 0
        local PercentageY = typeof(PercentageY == "number") and math.clamp(PercentageY, 0, 1) or 0
        ColorPicker.Saturation[1] = PercentageX
        ColorPicker.Saturation[2] = 1 - PercentageY
        ColorPicker:Update()
    end

    local function UpdateAlpha(Percentage: number)
        local Percentage = typeof(Percentage == "number") and math.clamp(Percentage, 0, 1) or 0
        ColorPicker.Alpha = Percentage
        ColorPicker:Update()
    end

    local function UpdateHue(Percentage: number)
        local Percentage = typeof(Percentage == "number") and math.clamp(Percentage, 0, 1) or 0
        ColorPicker.Hue = Percentage
        ColorPicker:Update()
    end

    Saturation.InputBegan:Connect(function(Input: InputObject, Process: boolean)
        if (not Dragging.Gui and not Dragging.True) and (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            Dragging = {Gui = Saturation, True = true}
            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local Percentage = (InputPosition - Saturation.AbsolutePosition) / Saturation.AbsoluteSize
            UpdateSaturation(Percentage.X, Percentage.Y)
        end
    end)

    Alpha.InputBegan:Connect(function(Input: InputObject, Process: boolean)
        if (not Dragging.Gui and not Dragging.True) and (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            Dragging = {Gui = Alpha, True = true}
            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local Percentage = (InputPosition - Alpha.AbsolutePosition) / Alpha.AbsoluteSize
            UpdateAlpha(Percentage.Y)
        end
    end)

    Hue.InputBegan:Connect(function(Input: InputObject, Process: boolean)
        if (not Dragging.Gui and not Dragging.True) and (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            Dragging = {Gui = Hue, True = true}
            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local Percentage = (InputPosition - Hue.AbsolutePosition) / Hue.AbsoluteSize
            UpdateHue(Percentage.Y)
        end
    end)

    UserInput.InputChanged:Connect(function(Input: InputObject, Process: boolean)
        if (Dragging.Gui ~= Saturation and Dragging.Gui ~= Alpha and Dragging.Gui ~= Hue) then return end
        if not (UserInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
            Dragging = {Gui = nil, True = false}
            return
        end

        local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
        if (Input.UserInputType == Enum.UserInputType.MouseMovement) then
            if Dragging.Gui == Saturation then
                local Percentage = (InputPosition - Saturation.AbsolutePosition) / Saturation.AbsoluteSize
                UpdateSaturation(Percentage.X, Percentage.Y)
            end
            if Dragging.Gui == Alpha then
                local Percentage = (InputPosition - Alpha.AbsolutePosition) / Alpha.AbsoluteSize
                UpdateAlpha(Percentage.Y)
            end
            if Dragging.Gui == Hue then
                local Percentage = (InputPosition - Hue.AbsolutePosition) / Hue.AbsoluteSize
                UpdateHue(Percentage.Y)
            end
        end
    end)
    
    
    ColorPicker.Hue, ColorPicker.Saturation[1], ColorPicker.Saturation[2] = ColorPicker.Color:ToHSV()
    ColorPicker:Update()
    Container:UpdateSize(20)
    table.insert(Items, ColorPicker)
    return #Items
end


function Menu.ComboBox(Tab_Name: string, Container_Name: string, Name: string, Value: string, Value_Items: table, Callback: any, ToolTip: string): ComboBox
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "ComboBox", Name, UDim2.new(1, -10, 0, 15), UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    local Symbol = Instance.new("TextLabel")
    local List = Instance.new("ScrollingFrame")
    local ListLayout = Instance.new("UIListLayout")

    local ComboBox = {}
    ComboBox.Name = Name
    ComboBox.Class = "ComboBox"
    ComboBox.Tab = Tab_Name
    ComboBox.Container = Container_Name
    ComboBox.Index = #Items + 1
    ComboBox.Callback = typeof(Callback) == "function" and Callback or function() end
    ComboBox.Value = typeof(Value) == "string" and Value or ""
    ComboBox.Items = typeof(Value_Items) == "table" and Value_Items or {}

    local function UpdateValue(Value: string)
        ComboBox.Value = tostring(Value)
        Button.Text = ComboBox.Value or "[...]"
    end

    local ItemObjects = {}
    local function AddItem(Name: string)
        local Button = Instance.new("TextButton")
        Button.BackgroundColor3 = Menu.ItemColor
        Button.BorderColor3 = Color3.new()
        Button.BorderSizePixel = 0
        Button.Size = UDim2.new(1, 0, 0, 15)
        Button.Font = Enum.Font.SourceSans
        Button.Text = tostring(Name)
        Button.TextColor3 = ComboBox.Value == Button.Text and Menu.Accent or Color3.new(1, 1, 1)
        Button.TextSize = 14
        Button.TextTruncate = Enum.TextTruncate.AtEnd
        Button.Parent = List
        Button.MouseButton1Click:Connect(function()
            for _, v in ipairs(List:GetChildren()) do
                if v:IsA("GuiButton") then
                    if v == Button then continue end
                    v.TextColor3 = Color3.new(1, 1, 1)
                end
            end
            Button.TextColor3 = Menu.Accent
            UpdateValue(Button.Text)
            UpdateSelected()
            ComboBox.Callback(ComboBox.Value)
        end)
        AddEventListener(Button, function()
            Button.BackgroundColor3 = Menu.ItemColor
            if ComboBox.Value == Button.Text then
                Button.TextColor3 = Menu.Accent
            else
                Button.TextColor3 = Color3.new(1, 1, 1)
            end
        end)
        
        if #ComboBox.Items >= 6 then
            List.CanvasSize += UDim2.fromOffset(0, 15)
        end
        table.insert(ItemObjects, Button)
    end


    function ComboBox:Update(Value: string, Items: any)
        UpdateValue(Value)
        if typeof(Items) == "table" then
            for _, Button in ipairs(ItemObjects) do
                Button:Destroy()
            end
            table.clear(ItemObjects)

            List.CanvasSize = UDim2.new()
            List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(#self.Items * 15, 15, 90))
            for _, Item in ipairs(self.Items) do
                AddItem(tostring(Item))
            end
        else
            for _, Button in ipairs(ItemObjects) do
                Button.TextColor3 = self.Value == Button.Text and Menu.Accent or Color3.new(1, 1, 1)
            end
        end
    end

    function ComboBox:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function ComboBox:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 40 or -40, Label)
    end

    function ComboBox:GetValue(): table
        return self.Value
    end

    function ComboBox:SetValue(Value: string, Items: any)
        if typeof(Items) == "table" then
            self.Items = Items
        end
        self:Update(Value, self.Items)
    end


    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Button.Name = "Button"
    Button.BackgroundColor3 = Menu.ItemColor
    Button.BorderColor3 = Color3.new()
    Button.Position = UDim2.new(0, 0, 0, 20)
    Button.Size = UDim2.new(1, -40, 0, 15)
    Button.Font = Enum.Font.SourceSans
    Button.Text = ComboBox.Value
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Button.TextTruncate = Enum.TextTruncate.AtEnd
    Button.Parent = Label
    Button.MouseButton1Click:Connect(function()
        UpdateSelected(List, Button, UDim2.fromOffset(0, 15))
        List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(#ComboBox.Items * 15, 15, 90))
    end)
    AddEventListener(Button, function()
        Button.BackgroundColor3 = Menu.ItemColor
    end)

    Symbol.Name = "Symbol"
    Symbol.Parent = Button
    Symbol.BackgroundColor3 = Color3.new(1, 1, 1)
    Symbol.BackgroundTransparency = 1
    Symbol.Position = UDim2.new(1, -10, 0, 0)
    Symbol.Size = UDim2.new(0, 5, 1, 0)
    Symbol.Font = Enum.Font.SourceSans
    Symbol.Text = "-"
    Symbol.TextColor3 = Color3.new(1, 1, 1)
    Symbol.TextSize = 14

    List.Visible = false
    List.BackgroundColor3 = Menu.ItemColor
    List.BorderColor3 = Menu.BorderColor
    List.BorderMode = Enum.BorderMode.Inset
    List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(#ComboBox.Items * 15, 15, 90))
    List.Position = UDim2.fromOffset(20, 30)
    List.CanvasSize = UDim2.new()
    List.ScrollBarThickness = 4
    List.ScrollBarImageColor3 = Menu.Accent
    List.Parent = Label
    CreateStroke(List, Color3.new(), 1)
    AddEventListener(List, function()
        List.BackgroundColor3 = Menu.ItemColor
        List.BorderColor3 = Menu.BorderColor
        List.ScrollBarImageColor3 = Menu.Accent
    end)

    ListLayout.Parent = List

    ComboBox:Update(ComboBox.Value, ComboBox.Items)
    Container:UpdateSize(40)
    table.insert(Items, ComboBox)
    return #Items
end


function Menu.MultiSelect(Tab_Name: string, Container_Name: string, Name: string, Value_Items: table, Callback: any, ToolTip: string): MultiSelect
    local Container = GetContainer(Tab_Name, Container_Name)
    local Label = CreateLabel(Container.self, "MultiSelect", Name, UDim2.new(1, -10, 0, 15), UDim2.fromOffset(20, Container:GetHeight()))
    local Button = Instance.new("TextButton")
    local Symbol = Instance.new("TextLabel")
    local List = Instance.new("ScrollingFrame")
    local ListLayout = Instance.new("UIListLayout")

    local MultiSelect = {self = Label}
    MultiSelect.Name = Name
    MultiSelect.Class = "MultiSelect"
    MultiSelect.Tab = Tab_Name
    MultiSelect.Container = Container_Name
    MultiSelect.Index = #Items + 1
    MultiSelect.Callback = typeof(Callback) == "function" and Callback or function() end
    MultiSelect.Items = typeof(Value_Items) == "table" and Value_Items or {}
    MultiSelect.Value = {}


    local function GetSelectedItems(): table
        local Selected = {}
        for k, v in pairs(MultiSelect.Items) do
            if v == true then table.insert(Selected, k) end
        end
        return Selected
    end

    local function UpdateValue()
        MultiSelect.Value = GetSelectedItems()
        Button.Text = #MultiSelect.Value > 0 and table.concat(MultiSelect.Value, ", ") or "[...]"
    end

    local ItemObjects = {}
    local function AddItem(Name: string, Checked: boolean)
        local Button = Instance.new("TextButton")
        Button.BackgroundColor3 = Menu.ItemColor
        Button.BorderColor3 = Color3.new()
        Button.BorderSizePixel = 0
        Button.Size = UDim2.new(1, 0, 0, 15)
        Button.Font = Enum.Font.SourceSans
        Button.Text = Name
        Button.TextColor3 = Checked and Menu.Accent or Color3.new(1, 1, 1)
        Button.TextSize = 14
        Button.Parent = List
        Button.TextTruncate = Enum.TextTruncate.AtEnd
        Button.MouseButton1Click:Connect(function()
            MultiSelect.Items[Name] = not MultiSelect.Items[Name]
            Button.TextColor3 = MultiSelect.Items[Name] and Menu.Accent or Color3.new(1, 1, 1)
            UpdateValue()
            MultiSelect.Callback(MultiSelect.Items) -- don't send value
        end)
        AddEventListener(Button, function()
            Button.BackgroundColor3 = Menu.ItemColor
            Button.TextColor3 = table.find(GetSelectedItems(), Button.Text) and Menu.Accent or Color3.new(1, 1, 1)
        end)

        if GetDictionaryLength(MultiSelect.Items) >= 6 then
            List.CanvasSize += UDim2.fromOffset(0, 15)
        end
        table.insert(ItemObjects, Button)
    end


    function MultiSelect:Update(Value: any)
        if typeof(Value) == "table" then
            self.Items = Value
            UpdateValue()

            for _, Button in ipairs(ItemObjects) do
                Button:Destroy()
            end
            table.clear(ItemObjects)

            List.CanvasSize = UDim2.new()
            List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(GetDictionaryLength(self.Items) * 15, 15, 90))
            for Name, Checked in pairs(self.Items) do
                AddItem(tostring(Name), Checked)
            end
        else
            local Selected = GetSelectedItems()
            for _, Button in ipairs(ItemObjects) do
                local Checked = table.find(Selected, Button.Text)
                Button.TextColor3 = Checked and Menu.Accent or Color3.new(1, 1, 1)
            end
        end
    end

    function MultiSelect:SetLabel(Name: string)
        Label.Text = tostring(Name)
    end

    function MultiSelect:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if Label.Visible == Visible then return end
        
        Label.Visible = Visible
        Container:UpdateSize(Visible and 40 or -40, Label)
    end

    function MultiSelect:GetValue(): table
        return self.Items
    end

    function MultiSelect:SetValue(Value: any)
        self:Update(Value)
    end


    Label.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, Label)
        end
    end)
    Label.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)

    Button.BackgroundColor3 = Menu.ItemColor
    Button.BorderColor3 = Color3.new()
    Button.Position = UDim2.new(0, 0, 0, 20)
    Button.Size = UDim2.new(1, -40, 0, 15)
    Button.Font = Enum.Font.SourceSans
    Button.Text = "[...]"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Button.TextTruncate = Enum.TextTruncate.AtEnd
    Button.Parent = Label
    Button.MouseButton1Click:Connect(function()
        UpdateSelected(List, Button, UDim2.fromOffset(0, 15))
        List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(GetDictionaryLength(MultiSelect.Items) * 15, 15, 90))
    end)
    AddEventListener(Button, function()
        Button.BackgroundColor3 = Menu.ItemColor
    end)

    Symbol.Name = "Symbol"
    Symbol.BackgroundTransparency = 1
    Symbol.Position = UDim2.new(1, -10, 0, 0)
    Symbol.Size = UDim2.new(0, 5, 1, 0)
    Symbol.Font = Enum.Font.SourceSans
    Symbol.Text = "-"
    Symbol.TextColor3 = Color3.new(1, 1, 1)
    Symbol.TextSize = 14
    Symbol.Parent = Button

    List.Visible = false
    List.BackgroundColor3 = Menu.ItemColor
    List.BorderColor3 = Menu.BorderColor
    List.BorderMode = Enum.BorderMode.Inset
    List.Size = UDim2.fromOffset(Button.AbsoluteSize.X, math.clamp(GetDictionaryLength(MultiSelect.Items) * 15, 15, 90))
    List.Position = UDim2.fromOffset(20, 30)
    List.CanvasSize = UDim2.new()
    List.ScrollBarThickness = 4
    List.ScrollBarImageColor3 = Menu.Accent
    List.Parent = Label
    CreateStroke(List, Color3.new(), 1)
    AddEventListener(List, function()
        List.BackgroundColor3 = Menu.ItemColor
        List.BorderColor3 = Menu.BorderColor
        List.ScrollBarImageColor3 = Menu.Accent
    end)

    ListLayout.Parent = List

    MultiSelect:Update(MultiSelect.Items)
    Container:UpdateSize(40)
    table.insert(Items, MultiSelect)
    return #Items
end


function Menu.ListBox(Tab_Name: string, Container_Name: string, Name: string, Multi: boolean, Value_Items: table, Callback: any, ToolTip: string): ListBox
    local Container = GetContainer(Tab_Name, Container_Name)
    local List = Instance.new("ScrollingFrame")
    local ListLayout = Instance.new("UIListLayout")

    local ListBox = {self = Label}
    ListBox.Name = Name
    ListBox.Class = "ListBox"
    ListBox.Tab = Tab_Name
    ListBox.Container = Container_Name
    ListBox.Index = #Items + 1
    ListBox.Method = Multi and "Multi" or "Default"
    ListBox.Items = typeof(Value_Items) == "table" and Value_Items or {}
    ListBox.Value = {}
    ListBox.Callback = typeof(Callback) == "function" and Callback or function() end

    local ItemObjects = {}

    local function GetSelectedItems(): table
        local Selected = {}
        for k, v in pairs(ListBox.Items) do
            if v == true then table.insert(Selected, k) end
        end
        return Selected
    end

    local function UpdateValue(Value: any)
        if ListBox.Method == "Default" then
            ListBox.Value = tostring(Value)
        else
            ListBox.Value = GetSelectedItems()
        end
    end

    local function AddItem(Name: string, Checked: boolean)
        local Button = Instance.new("TextButton")
        Button.BackgroundColor3 = Menu.ItemColor
        Button.BorderColor3 = Color3.new()
        Button.BorderSizePixel = 0
        Button.Size = UDim2.new(1, 0, 0, 15)
        Button.Font = Enum.Font.SourceSans
        Button.Text = Name
        Button.TextSize = 14
        Button.TextXAlignment = Enum.TextXAlignment.Left
        Button.TextTruncate = Enum.TextTruncate.AtEnd
        Button.Parent = List
        if ListBox.Method == "Default" then
            Button.TextColor3 = ListBox.Value == Button.Text and Menu.Accent or Color3.new(1, 1, 1)
            Button.MouseButton1Click:Connect(function()
                for _, v in ipairs(List:GetChildren()) do
                    if v:IsA("GuiButton") then
                        if v == Button then continue end
                        v.TextColor3 = Color3.new(1, 1, 1)
                    end
                end
                Button.TextColor3 = Menu.Accent
                UpdateValue(Button.Text)
                UpdateSelected()
                ListBox.Callback(ListBox.Value)
            end)
            AddEventListener(Button, function()
                Button.BackgroundColor3 = Menu.ItemColor
                if ListBox.Value == Button.Text then
                    Button.TextColor3 = Menu.Accent
                else
                    Button.TextColor3 = Color3.new(1, 1, 1)
                end
            end)
            
            if #ListBox.Items >= 6 then
                List.CanvasSize += UDim2.fromOffset(0, 15)
            end
        else
            Button.TextColor3 = Checked and Menu.Accent or Color3.new(1, 1, 1)
            Button.MouseButton1Click:Connect(function()
                ListBox.Items[Name] = not ListBox.Items[Name]
                Button.TextColor3 = ListBox.Items[Name] and Menu.Accent or Color3.new(1, 1, 1)
                UpdateValue()
                UpdateSelected()
                ListBox.Callback(ListBox.Value)
            end)
            AddEventListener(Button, function()
                Button.BackgroundColor3 = Menu.ItemColor
                if table.find(ListBox.Value, Name) then
                    Button.TextColor3 = Menu.Accent
                else
                    Button.TextColor3 = Color3.new(1, 1, 1)
                end
            end)
            
            if GetDictionaryLength(ListBox.Items) >= 10 then
                List.CanvasSize += UDim2.fromOffset(0, 15)
            end
        end
        table.insert(ItemObjects, Button)
    end


    function ListBox:Update(Value: string, Items: any)
        if self.Method == "Default" then
            UpdateValue(Value)
        end
        if typeof(Items) == "table" then
            if self.Method == "Multi" then
                self.Items = Value
                UpdateValue()
            end
            for _, Button in ipairs(ItemObjects) do
                Button:Destroy()
            end
            table.clear(ItemObjects)

            List.CanvasSize = UDim2.new()
            List.Size = UDim2.new(1, -50, 0, 150)
            if self.Method == "Default" then
                for _, Item in ipairs(self.Items) do
                    AddItem(tostring(Item))
                end
            else
                for Name, Checked in pairs(self.Items) do
                    AddItem(tostring(Name), Checked)
                end
            end
        else
            if self.Method == "Default" then
                for _, Button in ipairs(ItemObjects) do
                    Button.TextColor3 = self.Value == Button.Text and Menu.Accent or Color3.new(1, 1, 1)
                end
            else
                local Selected = GetSelectedItems()
                for _, Button in ipairs(ItemObjects) do
                    local Checked = table.find(Selected, Button.Text)
                    Button.TextColor3 = Checked and Menu.Accent or Color3.new(1, 1, 1)
                end
            end
        end
    end

    function ListBox:SetVisible(Visible: boolean)
        if typeof(Visible) ~= "boolean" then return end
        if List.Visible == Visible then return end
        
        List.Visible = Visible
        Container:UpdateSize(Visible and 155 or -155, List)
    end

    function ListBox:SetValue(Value: string, Items: any)
        if self.Method == "Default" then
            if typeof(Items) == "table" then
                self.Items = Items
            end
            self:Update(Value, self.Items)
        else
            self:Update(Value)
        end
    end

    function ListBox:GetValue(): table
        return self.Value
    end


    List.Name = "List"
    List.Active = true
    List.BackgroundColor3 = Menu.ItemColor
    List.BorderColor3 = Color3.new()
    List.Position = UDim2.fromOffset(20, Container:GetHeight())
    List.Size = UDim2.new(1, -50, 0, 150)
    List.CanvasSize = UDim2.new()
    List.ScrollBarThickness = 4
    List.ScrollBarImageColor3 = Menu.Accent
    List.Parent = Container.self
    List.MouseEnter:Connect(function()
        if ToolTip then
            Menu:SetToolTip(true, ToolTip, List)
        end
    end)
    List.MouseLeave:Connect(function()
        if ToolTip then
            Menu:SetToolTip(false)
        end
    end)
    CreateStroke(List, Color3.new(), 1)
    AddEventListener(List, function()
        List.BackgroundColor3 = Menu.ItemColor
        List.ScrollBarImageColor3 = Menu.Accent
    end)

    ListLayout.Parent = List

    if ListBox.Method == "Default" then
        ListBox:Update(ListBox.Value, ListBox.Items)
    else
        ListBox:Update(ListBox.Items)
    end
    Container:UpdateSize(155)
    table.insert(Items, ListBox)
    return #Items
end


function Menu.Notify(Content: string, Delay: number)
    assert(typeof(Content) == "string", "missing argument #1, (string expected got " .. typeof(Content) .. ")")
    local Delay = typeof(Delay) == "number" and Delay or 3

    local Text = Instance.new("TextLabel")
    local Notification = {
        self = Text,
        Class = "Notification"
    }

    Text.Name = "Notification"
    Text.BackgroundTransparency = 1
    Text.Position = UDim2.new(0.5, -100, 1, -150 - (GetDictionaryLength(Notifications) * 15))
    Text.Size = UDim2.new(0, 0, 0, 15)
    Text.Text = Content
    Text.Font = Enum.Font.SourceSans
    Text.TextSize = 17
    Text.TextColor3 = Color3.new(1, 1, 1)
    Text.TextStrokeTransparency = 0.2
    Text.TextTransparency = 1
    Text.RichText = true
    Text.ZIndex = 4
    Text.Parent = Notifications_Frame

    local function CustomTweenOffset(Offset: number)
        spawn(function()
            local Steps = 33
            for i = 1, Steps do
                Text.Position += UDim2.fromOffset(Offset / Steps, 0)
                RunService.RenderStepped:Wait()
            end
        end)
    end

    function Notification:Update()
        
    end

    function Notification:Destroy()
        Notifications[self] = nil
        Text:Destroy()

        local Index = 1
        for _, v in pairs(Notifications) do
            local self = v.self
            self.Position += UDim2.fromOffset(0, 15)
            Index += 1
        end
    end

    Notifications[Notification] = Notification
    
    local TweenIn  = TweenService:Create(Text, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0), {TextTransparency = 0})
    local TweenOut = TweenService:Create(Text, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0), {TextTransparency = 1})
    
    TweenIn:Play()
    CustomTweenOffset(100)
    
    TweenIn.Completed:Connect(function()
        delay(Delay, function()
            TweenOut:Play()
            CustomTweenOffset(100)

            TweenOut.Completed:Connect(function()
                Notification:Destroy()
            end)
        end)
    end)
end


function Menu.Prompt(Message: string, Callback: any, ...)
    do
        local Prompt = Menu.Screen:FindFirstChild("Prompt")
        if Prompt then Prompt:Destroy() end
    end

    local Prompt = Instance.new("Frame")
    local Title = Instance.new("TextLabel")

    local Height = -20
    local function CreateButton(Text, Callback, ...)
        local Arguments = {...}

        local Callback = typeof(Callback) == "function" and Callback or function() end
        local Button = Instance.new("TextButton")
        Button.Name = "Button"
        Button.BorderSizePixel = 0
        Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        Button.Size = UDim2.fromOffset(100, 20)
        Button.Position = UDim2.new(0.5, -50, 0.5, Height)
        Button.Text = Text
        Button.TextStrokeTransparency = 0.8
        Button.TextSize = 14
        Button.Font = Enum.Font.SourceSans
        Button.TextColor3 = Color3.new(1, 1, 1)
        Button.Parent = Prompt
        Button.MouseButton1Click:Connect(function() Prompt:Destroy() Callback(unpack(Arguments)) end)
        CreateStroke(Button, Color3.new(), 1)
        Height += 25
    end

    CreateButton("OK", Callback, ...)
    CreateButton("Cancel", function() Prompt:Destroy() end)


    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, 0, 0, 15)
    Title.Position = UDim2.new(0, 0, 0.5, -100)
    Title.Text = Message
    Title.TextSize = 14
    Title.Font = Enum.Font.SourceSans
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Parent = Prompt

    Prompt.Name = "Prompt"
    Prompt.BackgroundTransparency = 0.5
    Prompt.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Prompt.BorderSizePixel = 0
    Prompt.Size = UDim2.new(1, 0, 1, 36)
    Prompt.Position = UDim2.fromOffset(0, -36)
    Prompt.Parent = Menu.Screen
end


function Menu.Spectators(): Spectators
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local List = Instance.new("Frame")
    local ListLayout = Instance.new("UIListLayout")
    local Spectators = {self = Frame}
    Spectators.List = {}
    Menu.Spectators = Spectators


    Frame.Name = "Spectators"
    Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderMode = Enum.BorderMode.Inset
    Frame.Size = UDim2.fromOffset(250, 50)
    Frame.Position = UDim2.fromOffset(Menu.ScreenSize.X - Frame.Size.X.Offset, -36)
    Frame.Visible = false
    Frame.Parent = Menu.Screen
    CreateStroke(Frame, Color3.new(), 1)
    CreateLine(Frame, UDim2.new(0, 240, 0, 1), UDim2.new(0, 5, 0, 20))
    SetDraggable(Frame)
    
    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 5, 0, 5)
    Title.Size = UDim2.new(0, 240, 0, 15)
    Title.Font = Enum.Font.SourceSansSemibold
    Title.Text = "Spectators"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 14
    Title.Parent = Frame

    List.Name = "List"
    List.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    List.BorderColor3 = Color3.fromRGB(40, 40, 40)
    List.BorderMode = Enum.BorderMode.Inset
    List.Position = UDim2.new(0, 4, 0, 30)
    List.Size = UDim2.new(0, 240, 0, 10)
    List.Parent = Frame

    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = List


    local function UpdateFrameSize()
        local Height = ListLayout.AbsoluteContentSize.Y + 5
        Spectators.self:TweenSize(UDim2.fromOffset(250, math.clamp(Height + 50, 50, 5000)), nil, nil, 0.3, true)
        Spectators.self.List:TweenSize(UDim2.fromOffset(240, math.clamp(Height, 10, 5000)), nil, nil, 0.3, true)
    end


    function Spectators.Add(Name: string, Icon: string)
        Spectators.Remove(Name)
        local Object = Instance.new("Frame")
        local NameLabel = Instance.new("TextLabel")
        local IconImage = Instance.new("ImageLabel")
        local Spectator = {self = Object}

        Object.Name = "Object"
        Object.BackgroundTransparency = 1
        Object.Position = UDim2.new(0, 5, 0, 30)
        Object.Size = UDim2.new(0, 240, 0, 15)
        Object.Parent = List

        NameLabel.Name = "Name"
        NameLabel.BackgroundTransparency = 1
        NameLabel.Position = UDim2.new(0, 20, 0, 0)
        NameLabel.Size = UDim2.new(0, 230, 1, 0)
        NameLabel.Font = Enum.Font.SourceSans
        NameLabel.Text = tostring(Name)
        NameLabel.TextColor3 = Color3.new(1, 1, 1)
        NameLabel.TextSize = 14
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Parent = Object

        IconImage.Name = "Icon"
        IconImage.BackgroundTransparency = 1
        IconImage.Image = Icon or ""
        IconImage.Size = UDim2.new(0, 15, 0, 15)
        IconImage.Position = UDim2.new(0, 2, 0, 0)
        IconImage.Parent = Object

        Spectators.List[Name] = Spectator
        UpdateFrameSize()
    end


    function Spectators.Remove(Name: string)
        if Spectators.List[Name] then
            Spectators.List[Name].self:Destroy()
            Spectators.List[Name] = nil
        end
        UpdateFrameSize()
    end


    function Spectators:SetVisible(Visible: boolean)
        self.self.Visible = Visible
    end


    return Spectators
end


function Menu.Keybinds(): Keybinds
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local List = Instance.new("Frame")
    local ListLayout = Instance.new("UIListLayout")
    local Keybinds = {self = Frame}
    Keybinds.List = {}
    Menu.Keybinds = Keybinds


    Frame.Name = "Keybinds"
    Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderMode = Enum.BorderMode.Inset
    Frame.Size = UDim2.fromOffset(250, 45)
    Frame.Position = UDim2.fromOffset(Menu.ScreenSize.X - Frame.Size.X.Offset, -36)
    Frame.Visible = false
    Frame.Parent = Menu.Screen
    CreateStroke(Frame, Color3.new(), 1)
    CreateLine(Frame, UDim2.new(0, 240, 0, 1), UDim2.new(0, 5, 0, 20))
    SetDraggable(Frame)

    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 5, 0, 5)
    Title.Size = UDim2.new(0, 240, 0, 15)
    Title.Font = Enum.Font.SourceSansSemibold
    Title.Text = "Key binds"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 14
    Title.Parent = Frame

    List.Name = "List"
    List.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    List.BorderColor3 = Color3.fromRGB(40, 40, 40)
    List.BorderMode = Enum.BorderMode.Inset
    List.Position = UDim2.new(0, 4, 0, 30)
    List.Size = UDim2.new(0, 240, 0, 10)
    List.Parent = Frame

    ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Padding = UDim.new(0, 3)
    ListLayout.Parent = List

    local function UpdateFrameSize()
        local Height = ListLayout.AbsoluteContentSize.Y + 5
        Keybinds.self:TweenSize(UDim2.fromOffset(250, math.clamp(Height + 45, 45, 5000)), nil, nil, 0.3, true)
        Keybinds.self.List:TweenSize(UDim2.fromOffset(240, math.clamp(Height, 10, 5000)), nil, nil, 0.3, true)
    end

    function Keybinds.Add(Name: string, State: string): Keybind
        Keybinds.Remove(Name)
        local Object = Instance.new("Frame")
        local NameLabel = Instance.new("TextLabel")
        local StateLabel = Instance.new("TextLabel")
        local Keybind = {self = Object}

        Object.Name = "Object"
        Object.BackgroundTransparency = 1
        Object.Position = UDim2.new(0, 5, 0, 30)
        Object.Size = UDim2.new(0, 230, 0, 15)
        Object.Parent = List

        NameLabel.Name = "Indicator"
        NameLabel.BackgroundTransparency = 1
        NameLabel.Position = UDim2.new(0, 5, 0, 0)
        NameLabel.Size = UDim2.new(0, 180, 1, 0)
        NameLabel.Font = Enum.Font.SourceSans
        NameLabel.Text = Name
        NameLabel.TextColor3 = Color3.new(1, 1, 1)
        NameLabel.TextSize = 14
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Parent = Object

        StateLabel.Name = "State"
        StateLabel.BackgroundTransparency = 1
        StateLabel.Position = UDim2.new(0, 190, 0, 0)
        StateLabel.Size = UDim2.new(0, 40, 1, 0)
        StateLabel.Font = Enum.Font.SourceSans
        StateLabel.Text = "[" .. tostring(State) .. "]"
        StateLabel.TextColor3 = Color3.new(1, 1, 1)
        StateLabel.TextSize = 14
        StateLabel.TextXAlignment = Enum.TextXAlignment.Right
        StateLabel.Parent = Object

        
        function Keybind:Update(State: string)
            StateLabel.Text = "[" .. tostring(State) .. "]"
        end

        function Keybind:SetVisible(Visible: boolean)
            if typeof(Visible) ~= "boolean" then return end
            if Object.Visible == Visible then return end
        
            Object.Visible = Visible
            UpdateFrameSize()
        end

        
        Keybinds.List[Name] = Keybind
        UpdateFrameSize()

        return Keybind
    end

    function Keybinds.Remove(Name: string)
        if Keybinds.List[Name] then
            Keybinds.List[Name].self:Destroy()
            Keybinds.List[Name] = nil
        end
        UpdateFrameSize()
    end

    function Keybinds:SetVisible(Visible: boolean)
        self.self.Visible = Visible
    end

    function Keybinds:SetPosition(Position: UDim2)
        self.self.Position = Position
    end

    return Keybinds
end


function Menu.Indicators(): Indicators
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local List = Instance.new("Frame")
    local ListLayout = Instance.new("UIListLayout")

    local Indicators = {self = Frame}
    Indicators.List = {}
    Menu.Indicators = Indicators

    Frame.Name = "Indicators"
    Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderMode = Enum.BorderMode.Inset
    Frame.Size = UDim2.fromOffset(250, 45)
    Frame.Position = UDim2.fromOffset(Menu.ScreenSize.X - Frame.Size.X.Offset, -36)
    Frame.Visible = false
    Frame.Parent = Menu.Screen
    CreateStroke(Frame, Color3.new(), 1)
    CreateLine(Frame, UDim2.new(0, 240, 0, 1), UDim2.new(0, 5, 0, 20))
    SetDraggable(Frame)

    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 5, 0, 5)
    Title.Size = UDim2.new(0, 240, 0, 15)
    Title.Font = Enum.Font.SourceSansSemibold
    Title.Text = "Indicators"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 14
    Title.Parent = Frame

    List.Name = "List"
    List.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    List.BorderColor3 = Color3.fromRGB(40, 40, 40)
    List.BorderMode = Enum.BorderMode.Inset
    List.Position = UDim2.new(0, 4, 0, 30)
    List.Size = UDim2.new(0, 240, 0, 10)
    List.Parent = Frame

    ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Padding = UDim.new(0, 3)
    ListLayout.Parent = List

    local function UpdateFrameSize()
        local Height = ListLayout.AbsoluteContentSize.Y + 12
        Indicators.self:TweenSize(UDim2.fromOffset(250, math.clamp(Height + 45, 45, 5000)), nil, nil, 0.3, true)
        Indicators.self.List:TweenSize(UDim2.fromOffset(240, math.clamp(Height, 10, 5000)), nil, nil, 0.3, true)
    end

    function Indicators.Add(Name: string, Type: string, Value: string, ...): Indicator
        Indicators.Remove(Name)
        local Object = Instance.new("Frame")
        local NameLabel = Instance.new("TextLabel")
        local StateLabel = Instance.new("TextLabel")

        local Indicator = {self = Object}
        Indicator.Type = Type
        Indicator.Value = Value

        Object.Name = "Object"
        Object.BackgroundTransparency = 1
        Object.Size = UDim2.new(0, 230, 0, 30)
        Object.Parent = Indicators.self.List
        
        NameLabel.Name = "Indicator"
        NameLabel.BackgroundTransparency = 1
        NameLabel.Position = UDim2.new(0, 5, 0, 0)
        NameLabel.Size = UDim2.new(0, 130, 0, 15)
        NameLabel.Font = Enum.Font.SourceSans
        NameLabel.Text = Name
        NameLabel.TextColor3 = Color3.new(1, 1, 1)
        NameLabel.TextSize = 14
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Parent = Indicator.self
    
        StateLabel.Name = "State"
        StateLabel.BackgroundTransparency = 1
        StateLabel.Position = UDim2.new(0, 180, 0, 0)
        StateLabel.Size = UDim2.new(0, 40, 0, 15)
        StateLabel.Font = Enum.Font.SourceSans
        StateLabel.Text = "[" .. tostring(Value) .. "]"
        StateLabel.TextColor3 = Color3.new(1, 1, 1)
        StateLabel.TextSize = 14
        StateLabel.TextXAlignment = Enum.TextXAlignment.Right
        StateLabel.Parent = Indicator.self


        if Type == "Bar" then
            local ObjectBase = Instance.new("Frame")
            local ValueLabel = Instance.new("TextLabel")

            ObjectBase.Name = "Bar"
            ObjectBase.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            ObjectBase.BorderColor3 = Color3.new()
            ObjectBase.Position = UDim2.new(0, 0, 0, 20)
            ObjectBase.Size = UDim2.new(0, 220, 0, 5)
            ObjectBase.Parent = Indicator.self
    
            ValueLabel.Name = "Value"
            ValueLabel.BorderSizePixel = 0
            ValueLabel.BackgroundColor3 = Menu.Accent
            ValueLabel.Text = ""
            ValueLabel.Parent = ObjectBase
            AddEventListener(ValueLabel, function()
                ValueLabel.BackgroundColor3 = Menu.Accent
            end)
        else
            Object.Size = UDim2.new(0, 230, 0, 15)
        end


        function Indicator:Update(Value: string, ...)
            if Indicators.List[Name] then
                if Type == "Text" then
                    self.Value = Value
                    Object.State.Text = Value
                elseif Type == "Bar" then
                    local Min, Max = select(1, ...)
                    self.Min = typeof(Min) == "number" and Min or self.Min
                    self.Max = typeof(Max) == "number" and Max or self.Max

                    local Scale = (self.Value - self.Min) / (self.Max - self.Min)
                    Object.State.Text = "[" .. tostring(self.Value) .. "]"
                    Object.Bar.Value.Size = UDim2.new(math.clamp(Scale, 0, 1), 0, 0, 5)
                end
                self.Value = Value
            end
        end


        function Indicator:SetVisible(Visible: boolean)
            if typeof(Visible) ~= "boolean" then return end
            if Object.Visible == Visible then return end
            
            Object.Visible = Visible
            UpdateFrameSize()
        end

        
        Indicator:Update(Indicator.Value, ...)
        Indicators.List[Name] = Indicator
        UpdateFrameSize()
        return Indicator
    end


    function Indicators.Remove(Name: string)
        if Indicators.List[Name] then
            Indicators.List[Name].self:Destroy()
            Indicators.List[Name] = nil
        end
        UpdateFrameSize()
    end


    function Indicators:SetVisible(Visible: boolean)
        self.self.Visible = Visible
    end

    function Indicators:SetPosition(Position: UDim2)
        self.self.Position = Position
    end


    return Indicators
end


function Menu.Watermark(): Watermark
    local Watermark = {}
    Watermark.Frame = Instance.new("Frame")
    Watermark.Title = Instance.new("TextLabel")
    Menu.Watermark = Watermark

    Watermark.Frame.Name = "Watermark"
    Watermark.Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Watermark.Frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Watermark.Frame.BorderMode = Enum.BorderMode.Inset
    Watermark.Frame.Size = UDim2.fromOffset(250, 20)
    Watermark.Frame.Position = UDim2.fromOffset((Menu.ScreenSize.X - Watermark.Frame.Size.X.Offset) - 50, -25)
    Watermark.Frame.Visible = false
    Watermark.Frame.Parent = Menu.Screen
    CreateStroke(Watermark.Frame, Color3.new(), 1)
    CreateLine(Watermark.Frame, UDim2.new(0, 245, 0, 1), UDim2.new(0, 2, 0, 15))
    SetDraggable(Watermark.Frame)

    Watermark.Title.Name = "Title"
    Watermark.Title.BackgroundTransparency = 1
    Watermark.Title.Position = UDim2.new(0, 5, 0, -1)
    Watermark.Title.Size = UDim2.new(0, 240, 0, 15)
    Watermark.Title.Font = Enum.Font.SourceSansSemibold
    Watermark.Title.Text = ""
    Watermark.Title.TextColor3 = Color3.new(1, 1, 1)
    Watermark.Title.TextSize = 14
    Watermark.Title.RichText = true
    Watermark.Title.Parent = Watermark.Frame

    function Watermark:Update(Text: string)
        self.Title.Text = tostring(Text)
    end

    function Watermark:SetVisible(Visible: boolean)
        self.Frame.Visible = Visible
    end

    return Watermark
end


function Menu:Init()
    UserInput.InputBegan:Connect(function(Input: InputObject, Process: boolean) end)
    UserInput.InputEnded:Connect(function(Input: InputObject)
        if (Input.UserInputType == Enum.UserInputType.MouseButton1) then
            Dragging = {Gui = nil, True = false}
        end
    end)
    RunService.RenderStepped:Connect(function(Step: number)
        local Menu_Frame = Menu.Screen.Menu
        Menu_Frame.Position = UDim2.fromOffset(
            math.clamp(Menu_Frame.AbsolutePosition.X,   0, math.clamp(Menu.ScreenSize.X - Menu_Frame.AbsoluteSize.X, 0, Menu.ScreenSize.X    )),
            math.clamp(Menu_Frame.AbsolutePosition.Y, -36, math.clamp(Menu.ScreenSize.Y - Menu_Frame.AbsoluteSize.Y, 0, Menu.ScreenSize.Y - 36))
        )
        local Selected_Frame = Selected.Frame
        local Selected_Item = Selected.Item
        if (Selected_Frame and Selected_Item) then
            local Offset = Selected.Offset or UDim2.fromOffset()
            local Position = UDim2.fromOffset(Selected_Item.AbsolutePosition.X, Selected_Item.AbsolutePosition.Y)
            Selected_Frame.Position = Position + Offset
        end
    
        if Scaling.True then
            MenuScaler_Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            local Origin = Scaling.Origin
            local Size = Scaling.Size
    
            if Origin and Size then
                local Location = UserInput:GetMouseLocation()
                local NewSize = Location + (Size - Origin)
    
                Menu:SetSize(Vector2.new(
                    math.clamp(NewSize.X, Menu.MinSize.X, Menu.MaxSize.X),
                    math.clamp(NewSize.Y, Menu.MinSize.Y, Menu.MaxSize.Y)
                ))
            end
        else
            MenuScaler_Button.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        end
    
        Menu.Hue += math.clamp(Step / 100, 0, 1)
        if Menu.Hue >= 1 then Menu.Hue = 0 end
    
        if ToolTip.Enabled == true then
            ToolTip_Label.Text = ToolTip.Content
            ToolTip_Label.Position = UDim2.fromOffset(ToolTip.Item.AbsolutePosition.X, ToolTip.Item.AbsolutePosition.Y + 25)
        end
    end)
    Menu.Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        Menu.ScreenSize = Menu.Screen.AbsoluteSize
    end)
end

--


-- UI LIB ABOVE





--[[ lib demo

Menu.ComboBox("Aiming", "YES", "Combobox", "One", {"One", "Two", "Three"}, function(value)
    print(value)
end, "ComboBox Tooltip")

Menu.ColorPicker("Aiming", "YES", "Colorpicker", Color3.fromRGB(255, 0, 0), 1, function(value)
    print(value)
end, "Colorpicker Tooltip")

Menu.Slider("Aiming", "YES", "Slider", 1, 100, 50, "%", 0, function(value)
    print(value)
end, "Slider Tooltip")

Menu.Label("Aiming", "YES", "Label", "Label Tooltip")

Menu.CheckBox("Aiming", "YES", "Checkbox", false, function(value) 
print(value)
end, "Checkbox Tooltip")

Menu.TextBox("Aiming", "YES", "Textbox", ""..fraudfun., function(value)
print(value)
end, "Silent Aim Prediction")

Menu.Hotkey("Aiming", "YES", "Hotkey", nil, function(value)
    game:GetService("UserInputService").InputBegan:connect(function(input, Processed)
        if not Processed then
            if input.KeyCode == value then 

            end
        end
    end)
end, "Keybind Nigga")

Menu:SetTitle("fraud.lol")
Menu:SetVisible(true)
Menu:Init()

]]
local bronxfun = getgenv().bronxfun
local esplibrary = getgenv().esplibrary
Menu.Tab("Aiming")
Menu.Container("Aiming", "Aimbot", "Left")
Menu.Container("Aiming", "Aimbot FOV", "Left")
Menu.Container("Aiming", "Aimbot Snapline", "Left")
Menu.Container("Aiming", "Smoothing", "Left")

Menu.Container("Aiming", "Silent", "Right")
Menu.Container("Aiming", "Silent FOV", "Right")
Menu.Container("Aiming", "Silent Snapline", "Right")
Menu.Container("Aiming", "Silent Misc", "Right")
--
Menu.Tab("Visuals")
Menu.Container("Visuals", "ESP", "Left")
Menu.Container("Visuals", "ESP Settings", "Left")
Menu.Container("Visuals", "ESP Colors", "Right")
Menu.Container("Visuals", "World", "Right")
--
Menu.Tab("Misc")
Menu.Container("Misc", "Movement", "Left")
Menu.Container("Misc", "Gun Mods", "Right")
--[[ AIMBOT MAIN ]]--
Menu.CheckBox("Aiming", "Aimbot", "Enabled", false, function(v) 
    bronxfun.aiming.aimbot.enabled = v
end)
Menu.Hotkey("Aiming", "Aimbot", "Keybind", nil, function(v)
    bronxfun.aiming.aimbot.keybind = v
end)
Menu.ComboBox("Aiming", "Aimbot", "Target Part", "Head", {"Head", "HumanoidRootPart"}, function(v)
    bronxfun.aiming.aimbot.targetpart = v
end)
Menu.CheckBox("Aiming", "Aimbot", "Friend Check", false, function(v) 
    bronxfun.aiming.aimbot.friendcheck = v
end)
Menu.CheckBox("Aiming", "Aimbot", "Visible Check", false, function(v) 
    bronxfun.aiming.aimbot.visiblecheck = v
end)
Menu.CheckBox("Aiming", "Aimbot", "Alive Check", false, function(v) 
    bronxfun.aiming.aimbot.alivecheck = v
end)

--[[ AIMBOT FOV ]]--
Menu.CheckBox("Aiming", "Aimbot FOV", "Show FOV", false, function(v) 
    bronxfun.aiming.aimbot.showfov = v
end)
Menu.ColorPicker("Aiming", "Aimbot FOV", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.aiming.aimbot.fovcolor = v
end)
Menu.Slider("Aiming", "Aimbot FOV", "Radius", 0, 800, 100, "", 0, function(v)
    bronxfun.aiming.aimbot.fovradius = v
end)
Menu.Slider("Aiming", "Aimbot FOV", "Sides", 3, 100, 100, "", 0, function(v)
    bronxfun.aiming.aimbot.fovsides = v
end)

--[[ AIMBOT SNAPLINE ]]--
Menu.CheckBox("Aiming", "Aimbot Snapline", "Enabled", false, function(v) 
    bronxfun.aiming.aimbot.snapline = v
end)
Menu.ColorPicker("Aiming", "Aimbot Snapline", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.aiming.aimbot.fovcolor = v
end)

--[[ SMOOTHING ]]--
Menu.Slider("Aiming", "Smoothing", "Smoothing", 0, 2, 0, "", 2, function(v)
    bronxfun.aiming.aimbot.smoothing = v
end)
Menu.ComboBox("Aiming", "Smoothing", "Easing Style", "Linear", {"Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential"}, function(v)
    bronxfun.aiming.aimbot.smoothingstyle = Enum.EasingStyle[v]
end)
Menu.ComboBox("Aiming", "Smoothing", "Easing Direction", "InOut", {"InOut", "In", "Out"}, function(v)
    bronxfun.aiming.aimbot.easingdirection = Enum.EasingDirection[v]
end)
--[[  SILENT ]]--
Menu.CheckBox("Aiming", "Silent", "Enabled", false, function(v) 
    bronxfun.aiming.silent.enabled = v
end)
Menu.Hotkey("Aiming", "Silent", "Keybind", nil, function(v)
    bronxfun.aiming.silent.keybind = v
end)
Menu.ComboBox("Aiming", "Silent", "Target Part", "Head", {"Head", "HumanoidRootPart"}, function(v)
    bronxfun.aiming.silent.targetpart = v
end)
local silentclosest

Menu.ComboBox("Aiming", "Silent", "Targetting Mode", "Auto", {"Auto", "Target"}, function(v)
    silentclosest = nil
    bronxfun.aiming.silent.targetmode = v
end)
Menu.CheckBox("Aiming", "Silent", "Friend Check", false, function(v) 
    bronxfun.aiming.silent.friendcheck = v
end)
Menu.CheckBox("Aiming", "Silent", "Visible Check", false, function(v) 
    bronxfun.aiming.silent.visiblecheck = v
end)
Menu.CheckBox("Aiming", "Silent", "Alive Check", false, function(v) 
    bronxfun.aiming.silent.alivecheck = v
end)
--[[ SILENT FOV ]]--
Menu.CheckBox("Aiming", "Silent FOV", "Show FOV", false, function(v) 
    bronxfun.aiming.silent.showfov = v
end)
Menu.ColorPicker("Aiming", "Silent FOV", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.aiming.silent.fovcolor = v
end)
Menu.Slider("Aiming", "Silent FOV", "Radius", 0, 800, 100, "", 0, function(v)
    bronxfun.aiming.silent.fovradius = v
end)
Menu.Slider("Aiming", "Silent FOV", "Sides", 3, 100, 100, "", 0, function(v)
    bronxfun.aiming.silent.fovsides = v
end)
--[[ SILENT SNAPLINE ]]--
Menu.CheckBox("Aiming", "Silent Snapline", "Enabled", false, function(v) 
    bronxfun.aiming.silent.snapline = v
end)
Menu.ColorPicker("Aiming", "Silent Snapline", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.aiming.silent.fovcolor = v
end)
--[[ SILENT MISC ]]--
Menu.CheckBox("Aiming", "Silent Misc", "Wallbang", false, function(v) 
    bronxfun.aiming.silent.wallbang = v
end)
--[[ ESP ]]--
Menu.CheckBox("Visuals", "ESP", "Enabled", false, function(v) 
    esplibrary.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Boxes", false, function(v) 
    esplibrary.boxes.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Healthbars", false, function(v) 
    esplibrary.healthbars.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Health Text", false, function(v) 
    esplibrary.healthtext.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Names", false, function(v) 
    esplibrary.names.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Distance", false, function(v) 
    esplibrary.distance.enabled = v
end)
Menu.CheckBox("Visuals", "ESP", "Weapon", false, function(v) 
    esplibrary.weapon.enabled = v
end)
--[[ ESP SETTINGS ]]--
if identifyexecutor() ~= "Wave" then
    Menu.ComboBox("Visuals", "ESP Settings", "Type", "Bounding", {"Bounding", "3D"}, function(v)
        esplibrary.boxes.type = v
    end)
end
Menu.CheckBox("Visuals", "ESP Settings", "Name Uses DisplayName", false, function(v) 
    esplibrary.names.displaynames = v
end)

Menu.ComboBox("Visuals", "ESP Settings", "Distance Measurement", "Meters", {"Meters", "Studs"}, function(v)
    if v == "Meters" then
        esplibrary.distance_measurement = "m"
        esplibrary.distance_format = 0.4
    else
        esplibrary.distance_measurement = "s"
        esplibrary.distance_format = 1
    end
end)

Menu.ComboBox("Visuals", "ESP Settings", "Font", "UI", {"UI", "System", "Plex", "Monospace", "Pixel"}, function(v)
    esplibrary.textfont = v
end)
Menu.Slider("Visuals", "ESP Settings", "Text Size", 0, 16, 12, "", 0, function(v)
    esplibrary.textsize = v
end)
Menu.Slider("Visuals", "ESP Settings", "Max Distance", 0, 6000, 3000, "", 0, function(v)
    esplibrary.maxdistance = v
end)
--[[ ESP COLORS ]]--
Menu.ColorPicker("Visuals", "ESP Colors", "Box", Color3.fromRGB(255, 255, 255), 1, function(v)
    esplibrary.boxes.color = v
end)
Menu.ColorPicker("Visuals", "ESP Colors", "Name", Color3.fromRGB(255, 255, 255), 1, function(v)
   esplibrary.names.color = v 
end)
Menu.ColorPicker("Visuals", "ESP Colors", "Distance", Color3.fromRGB(255, 255, 255), 1, function(v)
    esplibrary.distance.color = v
end)
Menu.ColorPicker("Visuals", "ESP Colors", "Weapon", Color3.fromRGB(255, 255, 255), 1, function(v)
    esplibrary.weapon.color = v
end)

--[[ WORLD ]]--
Menu.CheckBox("Visuals", "World", "Ambient Color", false, function(v) 
    bronxfun.visuals.world.changeambient = v
end)
Menu.ColorPicker("Visuals", "World", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.visuals.world.ambient = v
end)
Menu.CheckBox("Visuals", "World", "Fog Color", false, function(v) 
    bronxfun.visuals.world.changefogcolor = v
end)
Menu.ColorPicker("Visuals", "World", "Color", Color3.fromRGB(255, 255, 255), 1, function(v)
    bronxfun.visuals.world.fogcolor = v
end)
Menu.CheckBox("Visuals", "World", "FOV", false, function(v) 
    bronxfun.visuals.world.changefov = v
end)
Menu.Slider("Visuals", "World", "Value", 0, 120, 70, "", 0, function(v)
    bronxfun.visuals.world.fov = v
end)

--[[ MOVEMENT ]]--
Menu.CheckBox("Misc", "Movement", "CFrame Speed", false, function(v) 
    bronxfun.misc.movement.cframespeed = v
end)
Menu.Hotkey("Misc", "Movement", "Keybind", nil, function(v)
    bronxfun.misc.movement.speedkeybind = v
end)
Menu.Slider("Misc", "Movement", "Speed", 0, 1.5, 0.5, "", 2, function(v)
    bronxfun.misc.movement.speed = v
end)
Menu.CheckBox("Misc", "Movement", "Noclip", false, function(v) 
    bronxfun.misc.movement.noclip = v
end)
--[[ GUN MODS]]--
Menu.CheckBox("Misc", "Gun Mods", "Max Ammo On Equip", false, function(v) 
    bronxfun.misc.gunmods.maxammoonequip = v
end)
Menu.CheckBox("Misc", "Gun Mods", "Silent Chambering", false, function(v) 
    bronxfun.misc.gunmods.nochambersound = v
end)

Menu.Tab("Settings")
Menu.Container("Settings", "Settings", "Left")




Menu.Hotkey("Settings", "Settings", "Menu Keybind", nil, function(value)
    game:GetService("UserInputService").InputBegan:connect(function(input, Processed)
        if not Processed then
            if input.KeyCode == value then 
                if Menu_Frame.Visible then
                    Menu_Frame.Visible = false
                else
                    Menu_Frame.Visible = true
                end
            end
        end
    end)
end, "menu bind")

Menu.ColorPicker("Settings", "Settings", "UI Color", Color3.fromHex("#00A3E0"), 1, function(value)
    Menu.Accent = value
end, "Colorpicker Tooltip")

Menu.Button("Settings", "Settings", "discord.gg/", function(value)
    local request = (syn and syn.request) or (http and http.request) or http_request or request
    local HttpService = game:GetService("HttpService")
    if request then
        request({
            Url = 'http://127.0.0.1:6463/rpc?v=1',
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
                Origin = 'https://discord.com'
            },
            Body = HttpService:JSONEncode({
                cmd = 'INVITE_BROWSER',
                nonce = HttpService:GenerateGUID(false),
                args = {code = ""}
            })
        })
    end
end, "joins discord server")

Menu:SetVisible(true)
Menu:Init()
local text = {"b", "br", "bro", "bron", "bronx", "bronx.", "bronx.l", "bronx.lo", "bronx.lol", "bronx.lol | ", "bronx.lol | n", "bronx.lol | ne", "bronx.lol | new", "bronx.lol | newp", "bronx.lol | newpo", "bronx.lol | newpor", "bronx.lol | newport", "bronx.lol | newport w", "bronx.lol | newport wa", "bronx.lol | newport was", "bronx.lol | newport was h", "bronx.lol | newport was he", "bronx.lol | newport was her", "bronx.lol | newport was here", "bronx.lol | newport was her", "bronx.lol | newport was he", "bronx.lol | newport was h", "bronx.lol | newport was", "bronx.lol | newport wa", "bronx.lol | newport w", "bronx.lol | newport", "bronx.lol | newpor", "bronx.lol | newpo", "bronx.lol | newp", "bronx.lol | new", "bronx.lol | ne", "bronx.lol | n", "bronx.lol |", "bronx.lol", "bronx.lo", "bronx.l", "bronx.", "bronx", "bron", "bro", "br", "b", ""}
task.spawn(function()
    while task.wait() do
        for _, txt in pairs(text) do
            task.wait(0.5)
            Menu:SetTitle(txt)
        end
    end
end)
