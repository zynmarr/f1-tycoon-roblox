-- EventsConfig | ReplicatedStorage > ModuleScript
-- Solo datos SEGUROS para el cliente (sin lógica de servidor)

local EventsConfig = {}

-- Cada entrada es visible por el cliente para la UI
-- La lógica real (onStart) está solo en el servidor
EventsConfig.list = {
	{
		id       = "tacos",
		label    = "Tacos",
		emoji    = "",
		imageId  = "rbxassetid://130034776309032",
		duration = 93,
	},
	{
		id       = "bloodmoon",
		label    = "Bloodmoon",
		emoji    = "",
		imageId  = "rbxassetid://121675142991242",
		duration = 67,
	},
}

-- Lookup rápido por id (solo para el cliente)
EventsConfig.byId = {}
for _, e in ipairs(EventsConfig.list) do
	EventsConfig.byId[e.id] = e
end

return EventsConfig