
// ---- REGLAS ------------------------------------------------

vida_baja               :- health(H) & H < 40.
ammo_baja               :- ammo(A) & A < 15.
enemigo_debil(EH)       :- health(H) & EH < H.
enemigo_casi_muerto(EH) :- EH < 20.
es_soldier(Type)        :- Type == 1.
// Ventaja clara sobre un soldier: su vida es al menos 30 pts menor
ventaja_sobre_soldier(EH) :- health(H) & EH < H - 30.

// ---- INICIO ------------------------------------------------

+flag(F) : team(200)
  <-
  !iniciar_defensa.

+!iniciar_defensa
  <-
  //.print("AXIS FieldOps: Iniciando patrulla defensiva");
  .reload;
  ?flag(F);
  .create_control_points(F, 25, 6, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +patrolling;
  +patrol_point(0).

+flag(F) : team(100)
  <-
  !iniciar_ataque.

+!iniciar_ataque
  <-
  //.print("ALLIED FieldOps: Iniciando ruta logistica hacia bandera");
  .reload;
  ?flag(F);
  .create_control_points(F, 20, 4, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L); 
  +patrolling;
  +patrol_point(0).

// ---- PATRULLA (ambos equipos) ------------------------------

+patrol_point(P) : total_control_points(T) & P < T & patrolling
  <-
  ?control_points(C);
  .nth(P, C, Dest);
  .goto(Dest).

+patrol_point(P) : team(200) & total_control_points(T) & P >= T & patrolling 
  <-
  -patrol_point(P);
  +patrol_point(0).

+patrol_point(P) : team(100) & total_control_points(T) & P >= T & patrolling 
  <-
  ?flag(F);
  .goto(F).

// Llegar a un punto de patrulla, entonces dejar ammo y avanzar
+target_reached(T) : patrolling & not en_interrupcion
  <-
  .reload;
  ?patrol_point(P);
  -+patrol_point(P + 1);
  -target_reached(T).

// ---- REANUDAR (retoma desde el punto actual, no desde 0) ---

+!reanudar_patrulla: patrol_point(P)
  <-
  //.print("ALLIED FieldOps: Reanudando patrulla");
  -en_interrupcion;
  +patrolling;
  -patrol_point(P);
  +patrol_point(P).

+!reanudar_patrulla: not patrol_point(P) & team(100)
  <-
  ?flag(F);
  .goto(F).

+!reanudar_patrulla: not patrol_point(P) & team(200)
  <-
  !iniciar_defensa.
  

// ---- SUPERVIVENCIA (vida baja) ---------------------------

// Ve un médico y vida baja → ir hacia él
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
    : vida_baja & Type == 2 & not en_interrupcion & Distance <= 10
  <-
  //.print("Vida baja, voy al médico (dist=", Distance, ")");
  +en_interrupcion;
  -patrolling;
  +buscando_cura;
  .goto(Position).

// Ve un medpack y vida baja → ir a recogerlo
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
    : Type == 1001 & not en_interrupcion & health(H) & H < 80
  <-
  //.print("Voy a por medpack");
  +en_interrupcion;
  -patrolling;
  +buscando_medpack;
  .goto(Position).

+target_reached(T) : buscando_cura
  <-
  -buscando_cura;
  //.print("Junto al médico, reanudando patrulla");
  !reanudar_patrulla.

+target_reached(T) : buscando_medpack
  <-
  -buscando_medpack;
  //.print("Medpack recogido, reanudando patrulla");
  !reanudar_patrulla.

// ---- MUNICIÓN PROPIA BAJA --------------------------------

+ammo_baja : not en_interrupcion & not llevando_bandera
  <-
  //.print("Ammo baja, generando ammopack propio");
  +en_interrupcion;
  -patrolling;
  +recargando_propio;
  .stop;
  .reload;
  +veces_rotado(0);
  !recargar.

+!recargar: packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) & TYPE == 1002 & veces_rotado(N)
  <-
  .goto(POS);
  -veces_rotado(N);
  !reanudar_patrulla.

+!recargar: not packs_in_fov(ID, 1002, ANGLE, DIST, HEALTH, POS) & veces_rotado(N) & N < 3
  <-
  -+veces_rotado(N+1);
  .turn(0.375);
  !recargar.

+!recargar: not packs_in_fov(ID, 1002, ANGLE, DIST, HEALTH, POS) & veces_rotado(N) & N == 3
  <-
  -veces_rotado(N);
  -recargando_propio;
  //.print("No he podido recargar");
  !reanudar_patrulla.

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) : TYPE == 1002 & ammo(A) & A < 50
  <-
  -patrolling;
  +en_interrupcion;
  +recargando_propio;
  .goto(POS).


// El ammopack cae donde estamos → pack_taken confirma recogida
+pack_taken(Type, N) : recargando_propio
  <-
  -recargando_propio;
  //.print("Ammo recargada (+", N, "), reanudando");
  !reanudar_patrulla.

// Salvavidas por si pack_taken no se dispara
+target_reached(T) : recargando_propio
  <-
  -recargando_propio;
  !reanudar_patrulla.

// ---- COMBATE AXIS (defensa) ------------------------------

// Enemigo NO es soldier, con menos vida que yo, entonces perseguir
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & enemigo_debil(Health) & not es_soldier(Type)
    & not en_interrupcion & Distance <= 10 & ammo(A) & A >= 15
  <-
  //.print("AXIS: Persiguiendo enemigo débil tipo = ", Type, " vida = ", Health);
  +en_interrupcion;
  -patrolling;
  +persiguiendo_enemigo(ID);
  .shoot(3, Position);
  .goto(Position).

// Enemigo es soldier y tengo ventaja clara (su vida < mi vida - 30), entonces perseguir
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & es_soldier(Type) & ventaja_sobre_soldier(Health)
    & not en_interrupcion  & Distance <= 10 & ammo(A) & A >= 15
  <-
  //.print("AXIS: Soldier muy débil (", Health, "), persiguiendo");
  +en_interrupcion;
  -patrolling;
  +persiguiendo_enemigo(ID);
  .shoot(3, Position);
  .goto(Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & ammo(A) & A > 2 & persiguiendo_enemigo(ID)
  <-
  //.print("AXIS: Persigo y disparo al enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & ammo(A) & A > 2 & not persiguiendo_enemigo(I)
  <-
  //.print("AXIS: Disparando enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

// Llegamos a la posición del enemigo (muerto o se fue)
+target_reached(T) : persiguiendo_enemigo(I)
  <-
  -persiguiendo_enemigo(I);
  //.print("Posición de enemigo alcanzada, reanudando");
  !reanudar_patrulla.

// ---- PRIORIDAD 4: COMBATE ALLIED (ataque) ------------------
// Solo dispara, no persigue

// Seguir disparando mientras el enemigo esté en FOV (sin pararse ni cambiar rumbo)
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & ammo(A) & A >= 3 & not llevando_bandera & anant_flag
  <-
  //.print("ALLIED: Disparando enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position);
  -anant_flag;
  !reanudar_patrulla.

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & ammo(A) & A >= 3 & not llevando_bandera
  <-
  //.print("ALLIED: Disparando enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

// ---- BANDERA -----------------------------------------------

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) : team(100) & TYPE == 1003 & DIST < 10 & not enemies_in_fov(I,T,A,D,H,P)
  <-
  //.print("ALLIED: Bandera libre, voy a por ella");
  +en_interrupcion;
  -patrolling;
  +anant_flag;
  .goto(POS).

+flag_taken : team(100)
  <-
  !tengo_bandera.

+!tengo_bandera: not llevando_bandera
  <-
  +en_interrupcion;
  //.print("ALLIED FieldOps: Tengo la bandera, voy a base!");
  ?base(B);
  .goto(B);
  +llevando_bandera.


// ---- PACK RECOGIDO (genérico) ------------------------------

//+pack_taken(Type, N)
//  <-
  //.print("Pack recogido: tipo=", Type, " cant=", N).
