local base64EncodeValue(name, value) = std.base64(value);
local base64EncodeObjectValues(dataObject) = std.mapWithKey(base64EncodeValue, dataObject);


local getWithDefault = function(obj, field, default=null) if std.objectHas(obj, field) then obj[field] else default;

{
  // Encode all values of a provided object with base64. Useful for creating Kubernetes Secrets.
  base64EncodeObjectValues:: base64EncodeObjectValues,

  // Return value of `field` in `obj` or `default` if `field` is not found
  getWithDefault:: getWithDefault
}
