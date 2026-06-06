Locale = {}
Locale.__index = Locale

function Locale:new(options)
    local self = setmetatable({}, Locale)
    self.phrases = options.phrases or {}
    self.warnOnMissing = options.warnOnMissing or false
    return self
end

function Locale:t(key, subs)
    local phrase = self.phrases
    for k in string.gmatch(key, '[^.]+') do
        if phrase[k] then
            phrase = phrase[k]
        else
            if self.warnOnMissing then
                print(('Missing locale key: %s'):format(key))
            end
            return key
        end
    end
    
    if type(phrase) == 'string' then
        if subs then
            for k, v in pairs(subs) do
                phrase = phrase:gsub('{{' .. k .. '}}', v)
            end
        end
        return phrase
    end
    
    return key
end
