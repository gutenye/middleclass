-----------------------------------------------------------------------------------------------------------------------
-- middleclass.lua - v2.0 (2011-08)
-- Enrique Garcia Cota - enrique.garcia.cota [AT] gmail [DOT] com
-- Based on YaciCode, from Julien Patte and LuaObject, from Sebastien Rocca-Serra
-----------------------------------------------------------------------------------------------------------------------

local _classes = setmetatable({}, {__mode = "k"})

local function _setClassDictionariesMetatables(klass)
  local dict = klass.__instanceDict
  dict.__index = dict

  local super = klass.super
  if super then
    local superStatic = super.static
    setmetatable(dict, super.__instanceDict)
    setmetatable(klass.static, { __index = function(_,k) return dict[k] or superStatic[k] end })
  else
    setmetatable(klass.static, { __index = function(_,k) return dict[k] end })
  end
end

local function _setClassMetatable(klass)
  setmetatable(klass, {
    __tostring = function() return "class " .. klass.name end,
    __index    = klass.static,
    __newindex = klass.__instanceDict,
    __call     = function(self, ...) return self:new(...) end
  })
end

local function _createClass(name, super)
  local klass = { name = name, super = super, static = {}, __mixins = {}, __instanceDict={} }

  _setClassDictionariesMetatables(klass)
  _setClassMetatable(klass)
  _classes[klass] = true

  return klass
end

local function _createLookupMetamethod(klass, name)
  return function(...)
    local method = klass.super[name]
    assert( type(method)=='function', tostring(klass) .. " doesn't implement metamethod '" .. name .. "'" )
    return method(...)
  end
end

local function _setClassMetamethods(klass)
  for _,m in ipairs(klass.__metamethods) do
    klass[m]= _createLookupMetamethod(klass, m)
  end
end

local function _setDefaultInitializeMethod(klass, super)
  klass.initialize = function(instance, ...)
    return super.initialize(instance, ...)
  end
end

local function _includeMixin(klass, mixin)
  assert(type(mixin)=='table', "mixin must be a table")
  for name,method in pairs(mixin) do
    if name ~="included" then klass[name] = method end
  end
  if type(mixin.included)=="function" then mixin:included(klass) end
  klass.__mixins[mixin] = true
end

Object = _createClass("Object", nil)

Object.static.__metamethods = { '__add', '__call', '__concat', '__div', '__le', '__lt', 
                                '__mod', '__mul', '__pow', '__sub', '__tostring', '__unm' }

function Object.static:allocate()
  assert(_classes[self], "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
  return setmetatable({ class = self }, self.__instanceDict)
end

function Object.static:new(...)
  local instance = self:allocate()
  instance:initialize(...)
  return instance
end

function Object.static:subclass(name)
  assert(_classes[self], "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
  assert(type(name) == "string", "You must provide a name(string) for your class")

  local subclass = _createClass(name, self)
  _setClassMetamethods(subclass)
  _setDefaultInitializeMethod(subclass, self)
  self:subclassed(subclass)

  return subclass
end

function Object.static:subclassed(other) end

function Object.static:include( ... )
  assert(_classes[self], "Make sure you that you are using 'Class:include' instead of 'Class.include'")
  for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
  return self
end

function Object:initialize() end

function Object:__tostring() return "instance of " .. tostring(self.class) end

function class(name, super, ...)
  super = super or Object
  return super:subclass(name, ...)
end

function instanceOf(aClass, obj)
  if not _classes[aClass] or type(obj) ~= 'table' or not _classes[obj.class] then return false end
  if obj.class == aClass then return true end
  return subclassOf(aClass, obj.class)
end

function subclassOf(other, aClass)
  if not _classes[aClass] or not _classes[other] or aClass.super == nil then return false end
  return aClass.super == other or subclassOf(other, aClass.super)
end

function includes(mixin, aClass)
  if not _classes[aClass] then return false end
  if aClass.__mixins[mixin] then return true end
  return includes(mixin, aClass.super)
end

