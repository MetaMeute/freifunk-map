require "nodemap"

mymap = NodeMap:new()

mymap:addNodeWithId("00:22:b0:98:94:06", "10.702304,53.834384")
mymap:addNodeWithId("00:22:b0:44:94:b0", "10.792607,53.906532")
mymap:print()

print(mymap:toKML())

