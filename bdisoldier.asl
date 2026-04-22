// ---- INICIO ------------------------------------------------

+flag(F) : team(200)
  <-
  !iniciar_defensa.

+!iniciar_defensa
  <-
  //.print("AXIS Soldier: Iniciando patrulla defensiva");
  ?flag(F);
  .create_control_points(F, 20, 6, C);
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
  ?flag(F);
  .goto(F);
  +attacking.

// ---- PATRULLA (ambos equipos) ------------------------------

+patrol_point(P) : team(200) & total_control_points(T) & P < T & patrolling
  <-
  ?control_points(C);
  .nth(P, C, Dest);
  .goto(Dest).

+patrol_point(P) : team(200) & total_control_points(T) & P >= T & patrolling 
  <-
  -patrol_point(P);
  +patrol_point(0).


+target_reached(T) : team(200) & patrolling & not en_interrupcion
  <-
  ?patrol_point(P);
  -+patrol_point(P + 1);
  -target_reached(T).

// ---- REANUDAR (retoma desde el punto actual, no desde 0) ---

+!reanudar_patrulla: patrol_point(P)
  <-
  //.print("ALLIED Soldier: Reanudando patrulla");
  -en_interrupcion;
  +patrolling;
  -patrol_point(P);
  +patrol_point(P).

+!reanudar_patrulla: not patrol_point(P) & team(200)
  <-
  !iniciar_defensa.
  

// ---- SUPERVIVENCIA (vida baja) -----------------------------

// Ve un medpack y vida baja, entonces va a recogerlo
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
    : Type == 1001 & not en_interrupcion & health(H) & H < 30
  <-
  //.print("Voy a por medpack");
  +en_interrupcion;
  -patrolling;
  +buscando_medpack;
  .goto(Position).

+target_reached(T) : buscando_medpack
  <-
  -buscando_medpack;
  //.print("Medpack recogido, reanudando patrulla");
  !reanudar_patrulla.

+packs_in_fov(ID, Type, ANGLE, DIST, HEALTH, Pos)
    : Type == 1001
  <-
    -ultimo_medpack(_);
    +ultimo_medpack(Pos).

+health(H) : H < 15 & ultimo_medpack(Pos) & not en_interrupcion
  <-
    //.print("Voy a por medpack");
    +en_interrupcion;
    -patrolling;
    +buscando_medpack;
    .goto(Pos);
    -ultimo_medpack(Pos).

// ---- MUNICIÓN BAJA ------------------------------------

// Ve un ammopack y municion baja, entonces va a recogerlo
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
    : Type == 1002 & not en_interrupcion & ammo(A) & A < 20
  <-
  //.print("Voy a por ammopack");
  +en_interrupcion;
  -patrolling;
  +buscando_ammopack;
  .goto(Position).

+target_reached(T) : buscando_ammopack
  <-
  -buscando_ammopack;
  //.print("Ammopack recogido, reanudando patrulla");
  !reanudar_patrulla.
  
+packs_in_fov(ID, Type, ANGLE, DIST, HEALTH, Pos)
    : Type == 1002
  <-
    -ultimo_ammopack(_);
    +ultimo_ammopack(Pos).  

+ammo(A) : A < 10 & ultimo_ammopack(Pos) & not en_interrupcion
<-
  //.print("Voy a por ammopack");
  +en_interrupcion;
  -patrolling;
  +buscando_ammopack;
  .goto(Pos);
  -ultimo_ammopack(Pos).
  
// ---- COMBATE AXIS (defensa) ----------------------------

// Enemigo, entonces lo persigue
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & not en_interrupcion & ammo(A) & A >= 6 & health(H) & H > 15
  <-
  //.print("AXIS: Persiguiendo enemigo");
  +en_interrupcion;
  -patrolling;
  +persiguiendo_enemigo(ID);
  .shoot(3, Position);
  .goto(Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(200) & ammo(A) & A >= 6 & health(H) & H > 15 & persiguiendo_enemigo(ID)
  <-
  //.print("AXIS: Persigo y disparo al enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

+health(H) : H < 15 & ultimo_medpack(Pos) & persiguiendo_enemigo(ID) & not llevando_bandera
  <-
    //.print("Voy a por medpack");
    -persiguiendo_enemigo(ID);
    +buscando_medpack;
    .goto(Pos).

+ammo(A) : A < 6 & ultimo_ammopack(Pos) & persiguiendo_enemigo(ID) & not llevando_bandera
<-
  //.print("Voy a por ammopack");
  -persiguiendo_enemigo(ID);
  +buscando_ammopack;
  .goto(Pos).

// Llegamos a la posición del enemigo (muerto o se fue)
+target_reached(T) : persiguiendo_enemigo(ID) & team(200)
  <-
  -persiguiendo_enemigo(ID);
  //.print("Posición de enemigo alcanzada, reanudando");
  !reanudar_patrulla.

// ---- COMBATE ALLIED (ataque) ----------------------------

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & not en_interrupcion & ammo(A) & A >= 6 & health(H) & H > 15 & not llevando_bandera & attacking
  <-
  //.print("AXIS: Persiguiendo enemigo");
  +en_interrupcion;
  -attacking;
  +persiguiendo_enemigo(ID);
  .shoot(3, Position);
  .goto(Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & ammo(A) & A >= 6 & health(H) & H > 15 & persiguiendo_enemigo(ID) & not llevando_bandera
  <-
  //.print("ALLIED: Persigo y disparo al enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

// Llegamos a la posición del enemigo (muerto o se fue)
+target_reached(T) : persiguiendo_enemigo(ID) & not llevando_bandera
  <-
  -persiguiendo_enemigo(ID);
  //.print("Posicion de enemigo alcanzada, reanudando");
  !reanudar_attacking.

+!reanudar_attacking
  <-
  +attacking;
  -en_interrupcion;
  ?flag(F);
  .goto(F).

// ---- BANDERA -----------------------------------------------

// Allied coge la bandera, entonces la entrega en base
+flag_taken : team(100)
  <-
  !tengo_bandera.

+!tengo_bandera: not llevando_bandera
  <-
  +en_interrupcion;
  -attacking;
  //.print("ALLIED FieldOps: Tengo la bandera, voy a base!");
  ?base(B);
  .goto(B);
  +llevando_bandera.


// ---- PACK RECOGIDO (genérico) ------------------------------

//+pack_taken(Type, N)
//  <-
  //.print("Pack recogido: tipo=", Type, " cant=", N).