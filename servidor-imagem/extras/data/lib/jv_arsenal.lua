-- Armas nomeadas de Ascensao. Mantem os sprites/IDs do cliente 8.60.
-- Identidade, atributos e requisitos sao gravados em cada instancia, nao no item base.
return {
    levels={400,600,800,1000}, evoStorage=79500,
    fragmentosStorage=79610, custos={200,250,300,12},
    chances={0.0035,0.005,0.0075,0.01,0.12},
    -- Chances por morte, independentes do rate de loot global.
    classicos={demon={tier=1,chance=0.002},juggernaut={tier=2,chance=0.005}},
    magia={1.15,1.30,1.45,1.65}, distancia={1.15,1.30,1.45,1.65},
    origem={'Demon / Caverna Infernal','Juggernaut / Forja Abissal / Cripta Ancestral','Covil dos Titas','Soberano Infernal'},
    familias={
        {chave='espada',classe=1,item=2400,artigo='uma',
         nomes={'Lamina do Despertar','Espada do Guardiao de Ferro','Lamina do Cavaleiro Abissal','Espada do Tita da Guerra'},
         ataque={65,78,94,112},defesa={40,44,48,54}},
        {chave='machado',classe=1,item=8925,artigo='um',
         nomes={'Machado do Despertar','Machado do Guardiao de Ferro','Cutelo Abissal','Machado do Tita da Guerra'},
         ataque={72,87,105,126},defesa={35,39,44,50}},
        {chave='martelo',classe=1,item=2421,artigo='um',
         nomes={'Martelo do Despertar','Martelo do Guardiao de Ferro','Quebraosso Abissal','Martelo do Tita da Guerra'},
         ataque={69,83,100,120},defesa={39,43,48,54}},
        {chave='arco',classe=2,item=8854,artigo='um',
         nomes={'Arco do Atirador Desperto','Arco da Sentinela Real','Arco do Rastreador Astral','Arco do Executor Divino'},
         ataque={10,18,28,42}},
        {chave='besta',classe=2,item=8851,artigo='uma',
         nomes={'Besta do Atirador Desperto','Besta da Sentinela Real','Besta do Rastreador Astral','Besta do Executor Divino'},
         ataque={12,21,32,48}},
        {chave='cetro',classe=3,item=8922,artigo='um',
         nomes={'Cetro do Canalizador','Cetro do Piromante','Cetro do Arcanista','Cetro do Arquimago'},
         ataque={140,185,240,310},magico=true},
        {chave='bastao',classe=4,item=2183,artigo='um',
         nomes={'Bastao do Naturalista','Bastao do Guardiao das Raizes','Bastao do Xama Ancestral','Bastao do Avatar da Natureza'},
         ataque={135,180,235,300},magico=true},
    },
}
