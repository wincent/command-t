local scanner = {}

-- TODO: think about lazy-loading these when actually needed
scanner.buffer = require('wincent.commandt.scanner.buffer')
scanner.help = require('wincent.commandt.scanner.help')

return scanner
