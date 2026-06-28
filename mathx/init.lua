---项目数学扩展库。
---本模块会有意扩展全局 math 表；角度相关工具
---统一使用度，原始 Lua 弧度函数保留在 mathx.raw 中。
---@class lib.mathx : mathlib
local g = math

local raw_random = math.random
local raw_sin = math.sin
local raw_asin = math.asin
local raw_cos = math.cos
local raw_atan = math.atan
local raw_floor = math.floor
local raw_ceil = math.ceil
local raw_pi = math.pi

g.raw = {
    random = raw_random,
    sin = raw_sin,
    asin = raw_asin,
    cos = raw_cos,
    atan = raw_atan,
    floor = raw_floor,
    ceil = raw_ceil,
    pi = raw_pi,
}

---@class lib.mathx.backend
---@field random_float? fun(min: number, max: number): number 随机浮点数后端
---@field random_int? fun(min: integer, max: integer): integer 可选随机整数后端
---@field sin? fun(angle: number): number 角度制正弦后端
---@field asin? fun(value: number): number 返回角度的反正弦后端
---@field cos? fun(angle: number): number 角度制余弦后端
---@field atan? fun(y: number, x: number): number 返回角度的反正切后端

---@type lib.mathx.backend
local backend = {}
local geometry

local backend_methods = {
    "random_float",
    "sin",
    "asin",
    "cos",
    "atan",
}

local lua_backend = {
    random_float = function(min, max)
        return min + raw_random() * (max - min)
    end,
    random_int = function(min, max)
        return raw_random(min, max)
    end,
    sin = function(angle)
        return raw_sin(angle * raw_pi / 180)
    end,
    asin = function(value)
        return raw_asin(value) * 180 / raw_pi
    end,
    cos = function(angle)
        return raw_cos(angle * raw_pi / 180)
    end,
    atan = function(y, x)
        return raw_atan(y, x) * 180 / raw_pi
    end,
}

local backend_depth = 0

local function raw_random_float(min, max)
    return min + raw_random() * (max - min)
end

local function raw_random_int(min, max)
    return raw_random(min, max)
end

local function call_backend(method_name, raw_fallback, ...)
    if backend_depth > 0 then
        return raw_fallback(...)
    end

    backend_depth = backend_depth + 1
    local ok, result = pcall(backend[method_name], ...)
    backend_depth = backend_depth - 1

    if not ok then
        error(result, 2)
    end
    return result
end

---@param next_backend lib.mathx.backend
function g.set_backend(next_backend)
    assert(type(next_backend) == "table", "mathx backend must be a table")
    for _, method_name in ipairs(backend_methods) do
        assert(type(next_backend[method_name]) == "function", "mathx backend." .. method_name .. " must be a function")
    end
    if next_backend.random_int ~= nil then
        assert(type(next_backend.random_int) == "function", "mathx backend.random_int must be a function")
    end
    backend = next_backend
end

function g.use_lua_backend()
    backend = lua_backend
end

g.use_lua_backend()

---通过向下取整把实数转为整数。
---@param x number
---@return integer
function g.r2i(x)
    return raw_floor(x)
end

---将数值四舍五入到最近整数，五成时远离 0 取整。
---@param x number
---@return integer
function g.round(x)
    if x >= 0 then
        return raw_floor(x + 0.5)
    end
    return raw_ceil(x - 0.5)
end

local function normalize_range(min, max, default_min, default_max)
    if min == nil then
        min, max = default_min, default_max
    elseif max == nil then
        min, max = default_min, min
    elseif max < min then
        min, max = max, min
    end
    return min, max
end

local function point_x(point)
    geometry = geometry or require "lib.mathx.geometry"
    return geometry.get_x(point)
end

local function point_y(point)
    geometry = geometry or require "mathx.geometry"
    return geometry.get_y(point)
end

---@param min? number 随机范围下限；只传一个值时表示上限
---@param max? number 随机范围上限；可小于下限
---@return number
local function random(min, max)
    min, max = normalize_range(min, max, 0, 2 ^ 32)
    return call_backend("random_float", raw_random_float, min, max)
end

---返回随机实数，min 和 max 可以反向传入。
---@param min? number 随机范围下限；只传一个值时表示上限
---@param max? number 随机范围上限；可小于下限
---@return number
function g.random_real(min, max)
    return random(min, max)
end

---返回随机角度，默认范围为 [-180, 180]。
---@param min? number 随机范围下限；只传一个值时表示上限
---@param max? number 随机范围上限；可小于下限
---@return number
function g.random_angle(min, max)
    min, max = normalize_range(min, max, -180, 180)
    return call_backend("random_float", raw_random_float, min, max)
end

---返回随机整数，min 和 max 可以反向传入。
---@param min integer
---@param max integer
---@return integer
function g.random_int(min, max)
    if min > max then
        min, max = max, min
    end
    if backend.random_int then
        return call_backend("random_int", raw_random_int, min, max)
    end
    return raw_random(min, max)
end

---@return integer
function g.random_sign()
    return (g.random_int(0, 1) == 0 and 1) or -1
end

---@param n number
---@return integer
function g.sign(n)
    if n == 0 then
        return 0
    end
    return (n > 0 and 1) or -1
end

---@type number
g.PI = raw_pi

---@param a number 角度，单位为度
---@return number radians 弧度
function g.angle2radian(a)
    return a * raw_pi / 180
end

---@param a number 角度，单位为度
---@return number radians 弧度
function g.a2r(a)
    return g.angle2radian(a)
end

---@param r number 弧度
---@return number angle 角度，单位为度
function g.radian2angle(r)
    return r / raw_pi * 180
end

---@param r number 弧度
---@return number angle 角度，单位为度
function g.r2a(r)
    return g.radian2angle(r)
end

---@param r number 半径
---@param d number 弧长
---@return number angle 角度，单位为度
function g.radian_rotate(r, d)
    assert(r ~= 0, "radius must not be zero")
    return d / (2 * raw_pi * r) * 360
end

---将角度规范到 [-180, 180] 范围。
---@param a number 角度，单位为度
---@return number angle 角度，单位为度
function g.angle_rule(a)
    local normalized = (a + 180) % 360 - 180
    if normalized == -180 and a > 0 then
        return 180
    end
    return normalized
end

---@param po lib.point 起点
---@param pt lib.point 终点
---@return number angle 角度，单位为度
function g.angle_vector(po, pt)
    return g.atan(point_y(pt) - point_y(po), point_x(pt) - point_x(po))
end

---@param a1 number 第一个角度，单位为度
---@param a2 number 第二个角度，单位为度
---@return number difference 绝对角度差，单位为度
function g.angle_abs(a1, a2)
    return g.abs(g.angle_subtract(a1, a2))
end

---@param a1 number 第一个角度，单位为度
---@param a2 number 第二个角度，单位为度
---@return number difference 有符号角度差，单位为度
function g.angle_subtract(a1, a2)
    return g.angle_rule(a1 - a2)
end

---@param a1 number 第一个角度，单位为度
---@param a2 number 第二个角度，单位为度
---@return integer
function g.angle_sign(a1, a2)
    return g.sign(g.angle_subtract(a1, a2))
end

---使用度计算正弦。
---@param a number 角度，单位为度
---@return number
function g.sin(a)
    return call_backend("sin", raw_sin, a)
end

---计算反正弦，结果单位为度。
---@param value number
---@return number angle 角度，单位为度
function g.asin(value)
    return call_backend("asin", raw_asin, value)
end

---使用度计算余弦。
---@param a number 角度，单位为度
---@return number
function g.cos(a)
    return call_backend("cos", raw_cos, a)
end

---计算反正切，结果单位为度。
---@param y number
---@param x number
---@return number angle 角度，单位为度
function g.atan(y, x)
    return call_backend("atan", raw_atan, y, x)
end

---@param a number 弧度
---@return number
function g.sin_radian(a)
    return raw_sin(a)
end

---@param a number 弧度
---@return number
function g.cos_radian(a)
    return raw_cos(a)
end

---@param value number
---@return number radians 弧度
function g.asin_radian(value)
    return raw_asin(value)
end

---@param y number
---@param x number
---@return number radians 弧度
function g.atan_radian(y, x)
    return raw_atan(y, x)
end

---@param po1 lib.point
---@param pt1 lib.point
---@param po2 lib.point
---@param pt2 lib.point
---@return number
function g.crossproduct(po1, pt1, po2, pt2)
    return (point_x(pt1) - point_x(po1)) * (point_y(pt2) - point_y(po2))
        - (point_x(pt2) - point_x(po2)) * (point_y(pt1) - point_y(po1))
end

---@param po1 lib.point
---@param pt1 lib.point
---@param po2 lib.point
---@param pt2 lib.point
---@param error_range? number 叉积接近 0 时视为共线的误差范围
---@return integer
function g.crossproduct_sign(po1, pt1, po2, pt2, error_range)
    local value = g.crossproduct(po1, pt1, po2, pt2)
    error_range = error_range or 0.1

    if value > -error_range and value < error_range then
        return 0
    end
    return (value > 0 and 1) or -1
end

---@param point_list lib.point[]
---@return lib.point? first 转向发生前的点
---@return lib.point? middle 转向顶点
---@return lib.point? last 转向发生后的点
function g.get_polygon_turning_vector(point_list)
    local sign_o
    local sum = #point_list
    if sum < 4 then
        return nil, nil, nil
    end

    for i = 1, sum do
        local p1 = point_list[i]
        local p2 = point_list[i + 1]
        local p3 = point_list[i + 2]
        if i == sum - 1 then
            p3 = point_list[1]
        elseif i == sum then
            p2 = point_list[1]
            p3 = point_list[2]
        end

        local sign = g.crossproduct_sign(p1, p2, p2, p3)

        if sign ~= 0 and sign_o ~= nil and sign ~= sign_o then
            return p1, p2, p3
        end

        if sign ~= 0 then
            sign_o = sign
        end
    end

    return nil, nil, nil
end

---@param point_list lib.point[]
---@return boolean
function g.is_concave_polygon(point_list)
    return g.get_polygon_turning_vector(point_list) ~= nil
end

---@param n number
---@return integer
function g.invert(n)
    return (n == 0 and 1) or 0
end

---将数值向 0 截断为整数。
---@param s number
---@return integer? value 转换后的整数；非数字输入返回 nil
function g.int(s)
    if type(s) ~= "number" then
        return nil
    end
    if s >= 0 then
        return raw_floor(s)
    end
    return raw_ceil(s)
end

---@param n number
---@return integer width
---@return integer height
function g.index_to_grid(n)
    local w = 1
    local h = 1

    local function is_bigger(width, height)
        return width * height >= n
    end

    while true do
        if is_bigger(w, h) then
            return w, h
        end
        if is_bigger(w + 1, h) then
            return w + 1, h
        end
        w = w + 1
        h = h + 1
    end
end

---@param n integer
---@param xt integer x 方向上限
---@return integer x
---@return integer y
function g.index_to_coord(n, xt)
    local x = (n - 1) % xt + 1
    local y = (n - 1) // xt + 1
    return x, y
end

---@param x integer
---@param y integer
---@param xt integer x 方向上限
---@return integer
function g.coord_to_index(x, y, xt)
    return x + (y - 1) * xt
end

---@type lib.mathx.geometry
geometry = require "lib.mathx.geometry"
g.geometry = geometry
g.spatial_hash_grid = require "lib.mathx.spatial_hash_grid"

return g
