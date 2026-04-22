
// ---- REGLAS ------------------------------------------------

vida_baja               :- health(H) & H < 30.
ammo_baja               :- ammo(A) & A < 20.
enemigo_debil(EH)       :- health(H) & (EH - 10) < H.
es_soldier(Type)        :- Type == 1.
// Ventaja clara sobre un soldier: su vida es al menos 30 pts menor
ventaja_sobre_soldier(EH) :- health(H) & EH < H - 40.

// ---- INICIO ------------------------------------------------

+flag(F) : team(200)
  <-
  !iniciar_defensa.

+!iniciar_defensa
  <-
  //.print("AXIS FieldOps: Iniciando patrulla defensiva");
  .cure;
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
  .cure;
  ?flag(F);
  .create_control_points(F, 20, 5, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);   //+patrol_point(0); +patrolling;
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
  .cure;
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
  

// ---- AMMO BAJA ---------------------------------------------

// Ve un fieldop y ammo baja, entonces va hacia él
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
    : ammo_baja & Type == 4 & not en_interrupcion & Distance <= 5
  <-
  //.print("Munición baja, voy al fieldop (dist = ", Distance, ")");
  +en_interrupcion;
  -patrolling;
  +buscando_municion;
  .goto(Position).

// Ve un ammopack y ammo baja, entonces va a recogerlo
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
    : Type == 1002 & not en_interrupcion & ammo(A) & A < 80 & Distance < 5
  <-
  //.print("Voy a por ammopack");
  +en_interrupcion;
  -patrolling;
  +buscando_ammopack;
  .goto(Position).

+target_reached(T) : buscando_municion
  <-
  -buscando_municion;
  //.print("Junto al fieldop, reanudando patrulla");
  !reanudar_patrulla.

+target_reached(T) : buscando_ammopack
  <-
  -buscando_ammopack;
  //.print("Ammopack recogido, reanudando patrulla");
  !reanudar_patrulla.

// ---- SALUD PROPIA BAJA ---------------------

//Genera una curacion y la busca, si no la encuentra lo ignora y sigue
+vida_baja : not en_interrupcion & not llevando_bandera
  <-
  //.print("Vida baja, generando medpack propio");
  +en_interrupcion;
  -patrolling;
  +curando_propio;
  .stop;
  .cure;
  +veces_rotado(0);
  !curarse.

+!curarse: packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) & TYPE == 1001 & veces_rotado(N)
  <-
  .goto(POS);
  -veces_rotado(N);
  !reanudar_patrulla.

+!curarse: not packs_in_fov(ID, 1001, ANGLE, DIST, HEALTH, POS) & veces_rotado(N) & N < 3
  <-
  -+veces_rotado(N+1);
  .turn(0.375);
  !curarse.

+!curarse: not packs_in_fov(ID, 1001, ANGLE, DIST, HEALTH, POS) & veces_rotado(N) & N == 3
  <-
  -veces_rotado(N);
  -curando_propio;
  //.print("No he podido recargar");
  !reanudar_patrulla.

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) : TYPE == 1001 & health(H) & H < 50
  <-
  -patrolling;
  +en_interrupcion;
  +curando_propio;
  .goto(POS).

+pack_taken(Type, N) : curando_propio
  <-
  -curando_propio;
  //.print("Health curada (+", N, "), reanudando");
  !reanudar_patrulla.

+target_reached(T) : curando_propio
  <-
  -curando_propio;
  !reanudar_patrulla.

// ---- SOPORTE DE SALUD A ALIADOS CERCANOS ---------------------

+friends_in_fov(ID, Type, Angle, Distance, Health, Position) 
    : Distance <= 6 & not en_interrupcion & Health <= 20
    & not vida_baja & not llevando_bandera
  <-
  //.print("Aliado cerca, dejando ammopack (dist = ", Distance, ")");
  +en_interrupcion;
  +curar_amigo;
  .goto(Position).

+target_reached(T) : curar_amigo
  <-
  -curar_amigo;
  .cure;
  !reanudar_patrulla.


// ---- PRIORIDAD 4: COMBATE AXIS (defensa) -------------------

// Enemigo no soldier, con menos vida que yo, entonces perseguir
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

// Enemigo es soldier y tengo ventaja clara (su vida < mi vida - 40), entonces perseguir
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
// Solo dispara, nunca huye

// Si esta yendo ya a por la bandera si ve un enemigo cancela ir a la bandera
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & ammo(A) & A >= 3 & not llevando_bandera & anant_flag
  <-
  -anant_flag;
  //.print("ALLIED: Disparando enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position);
  !reanudar_patrulla.

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
    : team(100) & ammo(A) & A >= 3 & not llevando_bandera
  <-
  //.print("ALLIED: Disparando enemigo tipo = ", Type, " vida = ", Health);
  .shoot(3, Position).

// ---- BANDERA -----------------------------------------------

//Si ve la bandera sin enemigos mientras patrulla va a por ella
+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS) : team(100) & TYPE == 1003 & DIST < 10 & not enemies_in_fov(I,T,A,D,H,P)
  <-
  //.print("ALLIED: Bandera libre, voy a por ella");
  +en_interrupcion;
  -patrolling;
  +anant_flag;
  .goto(POS).

// Allied coge la bandera, entonces la entrega en base
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


// ---- PACK RECOGIDO (generico) ------------------------------

//+pack_taken(Type, N)
//  <-
  //.print("Pack recogido: tipo=", Type, " cant=", N).
