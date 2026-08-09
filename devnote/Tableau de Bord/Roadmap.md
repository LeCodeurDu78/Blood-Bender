Roadmap de Développement 
## 🟢 Phase 1 : 
## 🟢 Phase 1 : Fondations & Déplacements (Terminée) 
- [x] Contrôleur FPS (Camera, Gravité, ZQSD) 
- [x] Component Santé / Sang (`HealthComponent.gd`) 
- [x] Dash de Phase Sanguine (Consomme 5 PV)
- [x] HUD de base avec barre de santé dynamique 
## 🟡 Phase 2 : Arsenal & Conversion de Sang (Terminée) 
- [x] Classe parente `WeaponBase.gd` 
- [x] `WeaponManager.gd` avec sélection de 4 armes
- [x] Morph Attack (Changer d'arme coûte 10 PV) 
- [x] Conversion automatique PV -> Munitions quand le chargeur est vide
- [x] Mannequin de test (`DummyEnemy.gd`)
## 🔴 Phase 3 : Stagger, Glory Kills & Extractions (En cours)
- [ ] Jauge de Stagger invisible sur `Enemy.gd`
- [ ] Mettre l'ennemi en brillance rouge à 100% Stagger pendant 3s 
- [ ] Interaction CàC (Glory Kill) : destruction + soin à 100% PV 
- [ ] Feedback visuel dans le HUD quand à portée d'exécution 
## ⚪ Phase 4 : Roue de Doping & Ralenti Temporel (À venir) 
- [ ] Roue d'action avec `Engine.time_scale = 0.2` 
- [ ] Implémentation du Buff + Crash (ex: Coagulation de Fer / Hémophilie)
- [ ] Cooldowns et UI de la roue 
## ⚪ Phase 5 : Familiers & Progression Metroidvania (À venir) 
- [ ] Système d'invocation avec réservation/coût unique
- [ ] Ordres ciblés aux familiers
- [ ] Grappin de Faux et portes de progression (Gating)