# Scrap Flight Simulator — plano

## Pitch
Você desce uma rampa gigante num **carrinho de supermercado**, decola e voa o mais longe que conseguir. Cada voo paga
moedas pela distância; com elas você prende motor, asas e foguete no carrinho para ir cada vez mais longe, passando
por cidade, fazenda, deserto e mar. Inspirado em Potty Racers / Learn to Fly, sem banheiro nem cocô.

## Pesquisa
- Gênero "lança, voa, melhora, repete" vivo no Roblox em 2026: **Launch** (canhão + upgrades de força e planeio, códigos
  ainda atualizados em out/2026), **Fly Up!** (dos criadores do Fly Race, com recorde de distância), **Fly IT!**
  (pets dão bônus de voo), **Launch a Wheel** (variante de arremesso).
- Os originais em Flash (Potty Racers 1–4) tinham 30+ upgrades (motores, asas, turbo), itens no ar que dão impulso e
  obstáculos que freiam.
- Como esses jogos morrem: o loop é solo (nada para fazer com amigos), a progressão acaba (o último upgrade chega rápido
  e não há para onde ir) e o mundo é vazio depois de certa distância.
- Fontes: [Launch codes](https://twinfinite.net/codes/launch-codes/), [Launch guia](https://earnaldo.com/blog/launch),
  [Fly Up!](https://www.roblox.com/games/123385110392842/Fly-Up), [Fly IT!](https://www.roblox.com/games/77204647411864/Fly-IT),
  [Potty Racers 4](https://www.seeles.ai/games/racing/potty-racers-4-flying-racing-adventure).

## Diferencial
~~Largada em grupo a cada 40 s~~ — **removida a pedido do usuário (20/10)**: cada jogador lança quando quiser, no
Espaço. O motivo social fica para depois (ideias: recorde do servidor ao vivo, fantasma do melhor voo de um amigo).

Extra: **zonas** ao longo do voo (Cidade → Fazenda → Deserto → Mar → Nuvens) com placas de distância, anéis de impulso
e moedas no ar. Chegar a uma zona nova pela primeira vez paga um prêmio e mostra um anúncio para o servidor.

## Loop principal
- **10 s:** desce a rampa, decola, segura Espaço para o foguete, inclina o carrinho (W/S) para planar, pega anéis.
- **5 min:** 5 a 8 voos, compra 2 a 4 upgrades, bate o recorde pessoal.
- **1 h:** chega a uma zona nova, troca de carrinho (corpo novo = mais leve e aerodinâmico), entra no placar global.

## Sistemas
1. **Dados** (DataStore com pcall, retentativa e BindToClose): moedas, níveis de upgrade, carrinho equipado, recorde,
   zonas visitadas. leaderstats: Moedas e Recorde.
2. **Upgrades** (Config/Upgrades): Motor (empuxo contínuo), Asas (sustentação), Foguete (empuxo extra no Espaço,
   duração = combustível), Rodas (velocidade na rampa). 10 níveis cada.
3. **Carrinhos** (Config/Carts): corpo do veículo, 5 tiers (carrinho comum, de feira, industrial, de corrida, dourado),
   cada um com multiplicador de arrasto e peso.
4. **Voo** (servidor dono da física): na rampa o carrinho é empurrado; ao sair da rampa entram `VectorForce`
   (sustentação, proporcional à velocidade² e ao nível da asa) e `LinearVelocity` só na direção da frente (motor e
   foguete). O cliente só manda "foguete ligado/desligado" e "inclinação"; o servidor valida o combustível.
5. **Pouso e prêmio:** quando o carrinho toca chão ou água, ou para de andar por 1 s, o servidor mede a distância
   horizontal da ponta da rampa e paga `distância × MoedasPorStud × multiplicadores`.
6. ~~Baterias~~ (removidas). Lançamento no Espaço (botão LAUNCH no celular); cada jogador tem uma pista na rampa, do meio para fora.
7. **Zonas e itens no ar:** anéis de impulso, moedas, placas de distância, prêmio de primeira visita.
8. **Spawner e reset:** monta o carrinho do jogador na rampa com as peças compradas; botão "Voltar à rampa" (e volta
   automática 3 s após o pouso).
9. **Loja:** tela com cada upgrade (nível atual, efeito, preço do próximo, Comprar) e aba de carrinhos.

## Progressão e economia (valores iniciais, vão para Config)
- MoedasPorStud = 0.2 (voo inicial ~150 studs ≈ 30 moedas).
- Preço do nível n = PreçoBase × 1.55^n. PreçoBase: Motor 25, Asas 30, Foguete 40, Rodas 20.
- Efeito por nível (do 0 ao 10): empuxo do motor 0 → 120, sustentação 0 → 0.9, foguete 0 → 260 de empuxo e 0 → 6 s de
  combustível, rodas +6% de velocidade por nível.
- Carrinhos: 0, 2.500, 25.000, 200.000, 1.500.000 moedas.
- Zonas: Cidade 0, Fazenda 600, Deserto 1.800, Mar 4.000, Nuvens 8.000 studs.
- Meta da v1: ~2 h para ver as Nuvens com um jogador ativo.

## Monetização
- Gamepasses: 2x Moedas (299), Foguete Duplo (combustível ×2, 199), Carrinho VIP dourado com rastro (149).
- Developer products: pacotes de moedas (49/149/399), Super Impulso (o próximo voo com empuxo ×2, 25).
- Tudo opcional; nenhum upgrade só existe pago.

## Mapa
- Uma colina alta com a **rampa principal** (larga, para 8 carrinhos lado a lado) e a rampa lateral solo.
- Lobby no topo: loja, quadro de recordes.
- Pista de voo reta para frente, com as 5 zonas em faixa, placas de distância a cada 100 studs e terreno que muda de
  material e cor por zona; a partir do Mar, água (pouso na água conta).
- Estilo: cartoon colorido, low poly, luz de fim de tarde.

## UI
- HUD: moedas, distância ao vivo, velocidade, barra de combustível, recorde.
- Tela de resultado (distância, moedas, recorde, zona nova).
- Loja (upgrades + carrinhos), botão "Voltar à rampa".

## Assets
- Modelos: 5 carrinhos, peças (motor de hélice, asas em 3 tamanhos, foguete em 3 tamanhos, rodas), rampa, lobby,
  placas, anéis de impulso, moeda, props das zonas (casas, celeiro, cactos, boias, nuvens).
- VFX: fogo do foguete, faíscas das rodas, rastro do vento, impacto no chão, respingo na água, coleta de anel/moeda.
- Sons: rodinha na rampa, vento, foguete, coleta, pouso, cair na água, compra.

## Fora da v1
Pets, troca entre jogadores, skins além do carrinho VIP, manobras/acrobacias com pontuação, obstáculos no ar, eventos.

## Fases
1. Código + loop principal com placeholders (dados, upgrades, voo, pouso, spawner, reset, loja simples).
2. Modelos 3D (carrinhos e peças, rampa, props das zonas).
3. UI + ícones.
4. Mapa e ambientação (zonas, placas, anéis).
5. VFX.
6. Som.
7. Animação (pose do jogador no carrinho, comemoração).
8. Polimento + monetização.
