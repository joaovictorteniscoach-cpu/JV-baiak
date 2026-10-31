-- JV Baiak: compatibilidade com o cliente 8.60 dos aplicativos (OTClientV8, PC e Android).
-- O Baiak Thunder manda algumas mensagens (ex.: "Bem-vindo ao JV Baiak!" e "Sua ultima
-- visita foi em...") com o tipo 5, que nao existe no 8.60: o aplicativo nao mostrava
-- a mensagem e escrevia "Unhandled onTextMessage message mode 51" na tela de avisos.
-- O tipo azul do console existe em todos os clientes 8.60.
MESSAGE_STATUS_BLUE_LIGHT = MESSAGE_STATUS_CONSOLE_BLUE
