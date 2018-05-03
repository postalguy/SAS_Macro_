/******************************* QUERY TEST ! Recharge & passes ************/

/*--------------------------OPTIONS GLOBALES----------------------------*/
%Include "/SAS92/data/segchurn/sas2/autoexec_dev.sas" ; 
libname HEB "/home/sassrv/sasuser.v92/Hebdo Prepaid" ;
libname t oracle User = &UserOracle Pass = &PassOracle Path = &PathOracle schema=BI_PROD ;
options compress=yes mprint=1 /*sumsize=max sortsize=max*/ threads=yes ;
libname z oracle User = &UserOracle Pass = &PassOracle Path = &PathOracle schema=DWNM ;

/******************ENVIRONEMENT SETUP****************/


/********CALCUL AUTOMATIQUE DES PERIODES*******/

%macro SCRIPT_MACROS ;
data _null_;

/*S1*/

TD= put(TODAY(),DATE9.);
TDch = put(TD,CHAR9.);

YY1= substr(TDch,6,4);

numsem = week(TODAY(),'w')-1;

if numsem < 10 then do;
SEMAINE1 = compress(YY1!!"0"!!numsem);
end ;
else do ;
SEMAINE1= compress(YY1!!numsem);
drop numsem ;
end ;
put SEMAINE1=;

firstS1= TODAY() - weekday(TODAY()) -5;
format firstS1 DATE9.;
lastS1 = firstS1+6;
format lastS1 DATE9.;

firstS2 = firstS1-7;
format firstS2 DATE9.;
lastS2 = lastS1 -7;
format lastS2 DATE9.;


firstS3 = firstS2-7;
format firstS3 DATE9.;
lastS3 = lastS2 -7;
format lastS3 DATE9.;


firstS4 = firstS3-7;
format firstS4 DATE9.;
lastS4 = lastS3 -7;
format lastS4 DATE9.;

put firstS1=;
put lastS1=;
put firstS2=;
put lastS2=;
put firstS3=;
put lastS3=;
put firstS4=;
put lastS4=;


call symput("S1",SEMAINE1);
call symput("FS1", put(firstS1, DATE9.));
call symput("LS1", put(lastS1, DATE9.));
call symput("FS2", put(firstS2, DATE9.));
call symput("LS2", put(lastS2, DATE9.));
call symput("FS3", put(firstS3, DATE9.));
call symput("LS3", put(lastS3, DATE9.));
call symput("FS4", put(firstS4, DATE9.));
call symput("LS4", put(lastS4, DATE9.));

FS1ch =  put(put(firstS1, DATE9.),CHAR9.);
FS1chYY = substr(FS1ch,6,4);

numsem2 = week(firstS1,'w') -1;
if numsem2 < 10 then do;
SEMAINE2 = compress(FS1chYY!!"0"!!numsem2);
end ;
else do ;
SEMAINE2=compress(FS1chYY!!numsem2);
drop numsem2 ;
end ;
put SEMAINE2=;
call symput("S2",SEMAINE2);
FS2ch =  put(put(firstS2, DATE9.),CHAR9.);
FS2chYY = substr(FS2ch,6,4);

numsem3 = week(firstS2,'w') -1;
if numsem3 < 10 then do;
SEMAINE3 = compress( FS2chYY!!"0"!!numsem3);
end ;
else do ;
SEMAINE3=compress(FS2chYY!!numsem3);
drop numsem3 ;
end ;
put SEMAINE3=;
call symput("S3",SEMAINE3);
FS3ch =  put(put(firstS3, DATE9.),CHAR9.);
FS3chYY = substr(FS3ch,6,4);


numsem4 = week(firstS3,'w') -1;
if numsem4 < 10 then do;
SEMAINE4 = compress( FS3chYY!!"0"!!numsem4);
end ;
else do ;
SEMAINE4=compress(FS3chYY!!numsem4);
drop numsem4 ;
end ;
put SEMAINE4=;
call symput("S4",SEMAINE4);
run;
*/
run; /*REMOVE*/
%mend ;


/*--------------------------MACRO RECHARGE----------------------------*/
/*--------------------------------------------------------------------*/
/*Param 1 : Date Debut*/
/*Param 2 : Date Fin*/

%macro recharge_querry(date1=,date2=) ;

/******************* Extraction recharge ******************************/
PROC SQL THREADS ;
   CREATE TABLE DETAILS_RECH AS 
   SELECT t1.COD_LINEA, 
          t1.ID_DIA, 
            (case when t1.ID_ORIGEN_RECARGA in ( 11 16 10 18 13 15) then 'SCRATCH' else 'DEALER' end) AS CANAL, 
            (SUM(t1.IMPORTE_RECARGA)) FORMAT=16.4 AS CA,
			count(*) as NB_RECH
      FROM T.DW_F_RECARGAS t1
      WHERE t1.ID_ORIGEN_RECARGA IN 
           (
           11 12 10 13 15 16 17 18 
           ) AND t1.ID_DIA BETWEEN "&date1.:0:0:0"dt AND "&date2.:0:0:0"dt
		   AND ID_PLAN_TARIFARIO IN (
		712 312 306 839 1441 309 97 792 240 18 599 594 595 1393 834 311 1414 14 792 851 226 1276 596 12 907 184 1016 851 838 1084 311 11 306 963 712 851 837 850 836 620 427 601 20 87 184
		   )
      GROUP BY t1.COD_LINEA, t1.ID_DIA, (CALCULATED CANAL);
QUIT;

proc sort data=DETAILS_RECH threads ; by COD_LINEA ID_DIA ; run ;

data _DETAILS_RECH ; set DETAILS_RECH ;
format L_ID_DIA DATETIME. ;
L_ID_DIA=lag(ID_DIA);
DUREE=datepart(ID_DIA)-datepart(L_ID_DIA) ;
run ;

data _DETAILS_RECH ; set _DETAILS_RECH ;
by COD_LINEA ;
if first.COD_LINEA then DUREE=. ;
run ;

data _DETAILS_RECH ; set _DETAILS_RECH;
if 0 < CA <= 5 then TR_RC=1 ;
else if CA <= 10 then TR_RC=2 ;
else if CA <= 20 then TR_RC=3 ;
else TR_RC=4 ;
run ;


PROC SQL THREADS ;
   CREATE TABLE F_DETAILS_RECH AS 
   SELECT t1.COD_LINEA, 
            (COUNT(t1.ID_DIA)) AS NB_JOUR_RECH, 
            (sum(case when t1.CANAL='SCRATCH' then NB_RECH else 0 end)) AS NB_RECH_SCR, 
            (sum(case when t1.CANAL='DEALER' then NB_RECH else 0 end)) AS NB_RECH_DEAL, 
			(sum(case when t1.CANAL='SCRATCH' then CA else 0 end)) AS CA_RECH_SCR, 
            (sum(case when t1.CANAL='DEALER' then CA else 0 end)) AS CA_RECH_DEAL, 
          SUM(t1.CA) as CA_RECH,
		  sum(NB_RECH) as NB_RECH,
		  mean(DUREE) as DUREE_MOY_RECH,
		  CV(DUREE) as CV_MOY_RECH,
		  sum(case when TR_RC=1 then NB_RECH else 0 end ) as NB_RECH_TR1 ,
		  sum(case when TR_RC=2 then NB_RECH else 0 end ) as NB_RECH_TR2 ,
		  sum(case when TR_RC=3 then NB_RECH else 0 end ) as NB_RECH_TR3 ,
		  sum(case when TR_RC=4 then NB_RECH else 0 end ) as NB_RECH_TR4
      FROM WORK._DETAILS_RECH t1
      GROUP BY t1.COD_LINEA;
QUIT;


data _null_;
numsem=week("&date1"d,'W')+1 ;
call symputx("nsem",numsem) ;
run ;

data F_DETAILS_RECH_&nsem. ; set F_DETAILS_RECH;
MMPR=CA_RECH/NB_RECH;
PCT_NB_RECH_SCR=NB_RECH_SCR/sum(of NB_RECH_SCR NB_RECH_DEAL) ;
PCT_NB_RECH_DEAL=NB_RECH_DEAL/sum(of NB_RECH_SCR NB_RECH_DEAL) ;
PCT_CA_RECH_SCR=CA_RECH_SCR/sum(of CA_RECH_SCR CA_RECH_DEAL) ;
PCT_CA_RECH_DEAL=CA_RECH_DEAL/sum(of CA_RECH_SCR CA_RECH_DEAL) ;

array tab{4} NB_RECH_TR1 NB_RECH_TR2 NB_RECH_TR3 NB_RECH_TR4 ;
array tab1{4} PCT_NB_TR1 PCT_NB_TR2 PCT_NB_TR3 PCT_NB_TR4 ;
do i=1 to 4 ;
tab1{i}=tab{i}/NB_RECH ;
end ;

numsem=week("&date1"d,'W')+1 ;

if numsem<10 then do ;
SEMAINE=compress(%substr(&date1,6,4)!!"0"!!numsem);
end ;
else do ;
SEMAINE=compress(%substr(&date1,6,4)!!numsem);
end ;

drop i numsem ;

run ;


/*******************Extraction de passes ***********************************/


/**** extractions de pass***/
Proc Sql threads;
Create Table PASS_ETOILE As
SELECT   
  DW_D_LINEA.COD_LINEA,
  DW_D_SERVICIO.DES_SERVICIO,
  COUNT(DW_F_MV_SVA.ID_SERVICIO) as id_serv,
  DW_D_TIEMPO_DIA.SEMANA
FROM
  z.DW_D_LINEA,
  z.DW_D_SERVICIO,
  z.DW_F_MV_SVA,
  z.DW_D_TIEMPO_DIA,
  z.DW_D_SITUACION
WHERE
  ( DW_D_LINEA.ID_LINEA=DW_F_MV_SVA.ID_LINEA  )
  AND  ( DW_F_MV_SVA.ID_DIA=DW_D_TIEMPO_DIA.ID_DIA  )
  AND  ( DW_F_MV_SVA.ID_SERVICIO=DW_D_SERVICIO.ID_SERVICIO  )
  AND  ( DW_F_MV_SVA.ID_SITUACION=DW_D_SITUACION.ID_SITUACION  )
  AND  (
  DW_D_SERVICIO.DES_SERVICIO  IN  ('ETX SubServ1', 'ETX SubServ2', 'ETX SubServ3', 'ETX SubServ4', 'ETX SubServ5', 'ETX SubServ6', 'ETX SubServ7', 'ETX SubServ8', 'ETX SubServ0', 'PR 5dh', 'Souscription PASS 1 Jour', 'PR15', '1.5 Go', 'PR 25 DH', 'Souscription PASS 10 Jours (7 Jours pr Voix)', '3Go/10j', '5 Go valid for 30 days', 'Souscription PASS 30 Jours', 'PR13', 'Promo "1Go-2jours" 10*3', '10Go valid for 30 days', 'Gratuité étoile On-Net')
  AND  DW_D_SITUACION.DES_SITUACION  IN  ('ACTIVATION')
  AND  DW_D_TIEMPO_DIA.ID_DIA BETWEEN "&date1.:0:0:0"dt AND "&date2.:0:0:0"dt
  )
GROUP BY
   DW_D_LINEA.COD_LINEA, 
  DW_D_SERVICIO.DES_SERVICIO, 
  DW_D_TIEMPO_DIA.SEMANA ;
Quit ;

/**** Segmentation de passes***/

PROC SQL;
   CREATE TABLE WORK.PASS_ETOILE_Seg AS 
   SELECT t1.COD_LINEA, 
          t1.SEMANA, 
          /* Service */
            (case when t1.DES_SERVICIO IN (
            'ETX SubServ0'	
            'ETX SubServ1'	
            'ETX SubServ2'	
            'ETX SubServ3'	
            'ETX SubServ4'	
            'ETX SubServ5'	
            'ETX SubServ6'	
            'ETX SubServ7'	
            'ETX SubServ8'	
            ) then "Etoile1" 
            else "Etoile3" 
            end) AS Service, 
          /* SUM_of_COUNT(DW_F_MV_SVA.ID_SERV */
            (SUM(t1.id_serv)) AS 'SUM_of_COUNT(DW_F_MV_SVA.ID_SERV'n
      FROM PASS_ETOILE t1
      GROUP BY t1.COD_LINEA, t1.SEMANA, (CALCULATED Service);
QUIT;

/**** Transposition de passes***/
proc sort data= PASS_ETOILE_Seg THREADS;
by COD_LINEA SEMANA;
run;

proc transpose data=PASS_ETOILE_Seg out=T_PASS_ETOILE_Seg(drop=_name_);
by COD_LINEA SEMANA ; id Service; var 'SUM_of_COUNT(DW_F_MV_SVA.ID_SERV'n ; run ;



/**** Jointure Recharge + passes***/
PROC SQL threads;
   CREATE TABLE Recharge_pass_&nsem. AS 
   SELECT t1.COD_LINEA, 
          t1.SEMAINE, 
          t1.NB_JOUR_RECH, 
          t1.NB_RECH_SCR, 
          t1.NB_RECH_DEAL, 
          t1.CA_RECH_SCR, 
          t1.CA_RECH_DEAL, 
          t1.CA_RECH, 
          t1.NB_RECH, 
          t1.DUREE_MOY_RECH, 
          t1.CV_MOY_RECH, 
          t1.NB_RECH_TR1, 
          t1.NB_RECH_TR2, 
          t1.NB_RECH_TR3, 
          t1.NB_RECH_TR4, 
          t1.MMPR, 
          t1.PCT_NB_RECH_SCR, 
          t1.PCT_NB_RECH_DEAL, 
          t1.PCT_CA_RECH_SCR, 
          t1.PCT_CA_RECH_DEAL, 
          t1.PCT_NB_TR1, 
          t1.PCT_NB_TR2, 
          t1.PCT_NB_TR3, 
          t1.PCT_NB_TR4, 
          t2.Etoile1, 
          t2.Etoile3
      FROM F_DETAILS_RECH_&nsem. t1 LEFT JOIN T_PASS_ETOILE_SEG t2 ON (t1.COD_LINEA = t2.COD_LINEA) AND (t1.SEMAINE
           = t2.SEMANA);
QUIT;
%mend ;

/************************PARTIE Recharge VALIDEE*************************/

/************************************************** TRAFIC OUT ********************************/

/*--------------------------MACRO Traf Out----------------------------*/
/*--------------------------------------------------------------------*/
/*Param 1 : Date Fin semaine le scripte retourne 7 jours en arriere*/


%macro traf_out(date=) ;

data _null_;
numsem=week("&date"d,'W')+1 ;
call symputx("nsem",numsem) ;
run ;

PROC SQL THREADS ;
   CREATE TABLE WORK.TRAF_OUT AS 
   SELECT t1.TELEFONO_ORIGEN, 
          t1.ID_DIA, 
            (SUM(t1.SEGUNDOS_AIRE)/60) FORMAT=8. AS MOU_TOT,
			count(*) as Nb_app_tot,
				/* OFFNET*/
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call IAM Mobile' 'Voice Call Inwi Mobile' 'Voice Call IAM Fix' 'Voice Call Inwi Fix')
			then SEGUNDOS_AIRE/60 else 0 end) as MOU_OffNet,
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call IAM Mobile' 'Voice Call Inwi Mobile' 'Voice Call IAM Fix' 'Voice Call Inwi Fix')
			then 1 else 0 end) as Nb_app_OffNet,
				/* ONNET*/
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call Mediel Mobile'
'Voice Call RBT'
'Voice Call Mediel Fix'
'Voice call 121'
)
			then SEGUNDOS_AIRE/60 else 0 end) as MOU_OnNet,
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call Mediel Mobile'
'Voice Call RBT'
'Voice Call Mediel Fix'
'Voice call 121')
			then 1 else 0 end) as Nb_app_OnNet,
				/* INTER*/
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call Int Zone1'
'Voice Call Int Zone2'
'Voice Call Int Zone3'
'Voice Call Int Zone4'
)
			then SEGUNDOS_AIRE/60 else 0 end) as MOU_Int,
			sum (case when DES_TIPO_LLAMADA  IN  ('Voice Call Int Zone1'
'Voice Call Int Zone2'
'Voice Call Int Zone3'
'Voice Call Int Zone4'
)
			then 1 else 0 end) as Nb_app_Int
FROM Z.DW_F_PREPAGO t1
	       left join  z.DW_D_TIPO_LLAMADA t2 on t1.ID_TIPO_LLAMADA = t2.ID_TIPO_LLAMADA
      WHERE t1.ID_DIA between ("&date.:00:00:00"dt - 6*24*3600) and "&date.:00:00:00"dt 
		 AND t1.ID_PLAN_TARIFARIO_ORIGEN IN (
		712 312 306 839 1441 309 97 792 240 18 599 594 595 1393 834 311 1414 14 792 851 226 1276 596 12 907 184 1016 851 838 1084 311 11 306 963 712 851 837 850 836 620 427 601 20 87 184
		   )

		AND t1.ID_SENTIDO IN (10 12 14)
      GROUP BY t1.TELEFONO_ORIGEN, t1.ID_DIA;
QUIT;

PROC SQL;
   CREATE TABLE WORK.TRAF_OUT AS 
   SELECT t1.TELEFONO_ORIGEN as COD_LINEA, 
            (COUNT(t1.ID_DIA)) AS NB_J_ACT_OUT, 
            (SUM(t1.MOU_TOT)) AS MOU_TOT, 
            (SUM(t1.Nb_app_tot)) AS Nb_app_tot, 
            (SUM(t1.MOU_OffNet)) AS MOU_OffNet, 
            (SUM(t1.Nb_app_OffNet)) AS Nb_app_OffNet, 
            (SUM(t1.MOU_OnNet)) AS MOU_OnNet, 
            (SUM(t1.Nb_app_OnNet)) AS Nb_app_OnNet, 
            (SUM(t1.MOU_Int)) AS MOU_Int, 
            (SUM(t1.Nb_app_Int)) AS Nb_app_Int
      FROM WORK.TRAF_OUT t1
      GROUP BY t1.TELEFONO_ORIGEN;
QUIT;


data V_TRAF_OUT_&nsem. ; set TRAF_OUT;
numsem=week("&date"d,'W')+1 ;

if numsem<10 then do ;
SEMAINE=compress(%substr(&date,6,4)!!"0"!!numsem);
end ;
else do ;
SEMAINE=compress(%substr(&date,6,4)!!numsem);
end ;

drop numsem ;
run  ;

%mend ;





/************************************************** TRAFIC IN ********************************/

/*--------------------------MACRO Traf IN----------------------------*/
/*--------------------------------------------------------------------*/
/*Param 1 : Date Fin semaine le scripte retourne 7 jours en arriere*/

/************************************************** TRAFIC IN ********************************/


%macro traf_in(date1=,date2=);

proc sql threads;
create table WORK.temp1 /*trafic on net*/as 
SELECT   
  DW_D_LINEA.COD_LINEA,
  DW_D_TIEMPO_SEMANA.SEMANA,
  
SUM(DW_F_PREPAGO.SEGUNDOS_AIRE) as MIN_OnNET_prp

FROM
  z.DW_D_LINEA,
  z.DW_D_TIEMPO_SEMANA,
  z.DW_F_PREPAGO,
  z.DW_D_SENTIDO,
  z.DW_D_TIEMPO_DIA
WHERE
  ( DW_D_TIEMPO_DIA.ID_DIA=DW_F_PREPAGO.ID_DIA  )
  AND  ( DW_D_LINEA.ID_LINEA=DW_F_PREPAGO.ID_LINEA_DESTINO  )
  AND  ( DW_D_SENTIDO.ID_SENTIDO=DW_F_PREPAGO.ID_SENTIDO  )
  AND  ( DW_D_TIEMPO_SEMANA.ID_SEMANA=DW_D_TIEMPO_DIA.ID_SEMANA  )
  AND  (
   DW_D_LINEA.ID_PLAN_TARIFARIO IN (
		712 312 306 839 1441 309 97 792 240 18 599 594 595 1393 834 311 1414 14 792 851 226 1276 596 12 907 184 1016 851 838 1084 311 11 306 963 712 851 837 850 836 620 427 601 20 87 184
		   )
		   AND
  DW_D_SENTIDO.DES_SENTIDO  =  'ORIGINAIRE DE MEDITEL'
  AND  DW_D_LINEA.DES_CONT_PREP  =  'PREPAYE'
  AND  DW_D_TIEMPO_DIA.ID_DIA  BETWEEN  "&date1.:00:00:00"dt AND "&date2.:00:00:00"dt
  )
GROUP BY
  DW_D_LINEA.COD_LINEA, 
  DW_D_TIEMPO_SEMANA.SEMANA
ORDER BY DW_D_LINEA.COD_LINEA, 
  DW_D_TIEMPO_SEMANA.SEMANA ;



  create table WORK.temp2 /*trafic off net*/ as
  SELECT   
  DW_D_LINEA.COD_LINEA,
  DW_D_TIEMPO_SEMANA.SEMANA,
  
SUM(DW_F_CONTRATO.SEGUNDOS_AIRE) as MIN_OnNET_pop

FROM
  z.DW_D_LINEA,
  z.DW_D_TIEMPO_SEMANA,
  z.DW_F_CONTRATO,
  z.DW_D_SENTIDO,
  z.DW_D_TIEMPO_DIA
WHERE
  ( DW_D_TIEMPO_DIA.ID_DIA=DW_F_CONTRATO.ID_DIA  )
  AND  ( DW_D_LINEA.ID_LINEA=DW_F_CONTRATO.ID_LINEA_DESTINO  )
  AND  ( DW_D_SENTIDO.ID_SENTIDO=DW_F_CONTRATO.ID_SENTIDO  )
  AND  ( DW_D_TIEMPO_SEMANA.ID_SEMANA=DW_D_TIEMPO_DIA.ID_SEMANA  )
  AND DW_D_LINEA.ID_PLAN_TARIFARIO IN (
		712 312 306 839 1441 309 97 792 240 18 599 594 595 1393 834 311 1414 14 792 851 226 1276 596 12 907 184 1016 851 838 1084 311 11 306 963 712 851 837 850 836 620 427 601 20 87 184
		   )
  AND  (
  DW_D_SENTIDO.DES_SENTIDO  =  'ORIGINAIRE DE MEDITEL'
  AND  DW_D_LINEA.DES_CONT_PREP  =  'PREPAYE'
  AND  DW_D_TIEMPO_DIA.ID_DIA  BETWEEN  "&date1.:00:00:00"dt AND "&date2.:00:00:00"dt
  )
GROUP BY
  DW_D_LINEA.COD_LINEA, 
  DW_D_TIEMPO_SEMANA.SEMANA 
ORDER BY   DW_D_LINEA.COD_LINEA, 
  DW_D_TIEMPO_SEMANA.SEMANA;

  create table WORK.temp3 /*trafic national & international*/ as 
  SELECT   
  DW_F_INTERCONEXION.TELEFONO_DESTINO as COD_LINEA,

SUM(case when DW_D_SUBRUTA.DES_RUTA  IN  ('INTERNATIONAL', 'INTERNATIONAL DEDIE', 'INTERNATIONAL WANA') then DW_F_INTERCONEXION.SEGUNDOS_AIRE else 0 end) as MIN_Inter,
  SUM(case when DW_D_SUBRUTA.DES_RUTA  IN  ('NATIONAL MC', 'NATIONAL') then DW_F_INTERCONEXION.SEGUNDOS_AIRE else 0 end) as MIN_offnet_NAT,
  DW_D_TIEMPO_DIA.SEMANA
FROM
  z.DW_F_INTERCONEXION,
  z.DW_D_SUBRUTA,
  z.DW_D_TIEMPO_DIA,
  z.DW_D_SENTIDO,
  z.DW_D_LINEA
WHERE
  ( DW_D_TIEMPO_DIA.ID_DIA=DW_F_INTERCONEXION.ID_DIA  )
  AND  ( DW_D_LINEA.ID_LINEA=DW_F_INTERCONEXION.ID_LINEA_DESTINO  )
  AND  ( DW_D_SENTIDO.ID_SENTIDO=DW_F_INTERCONEXION.ID_SENTIDO  )
  AND DW_F_INTERCONEXION.ID_PLAN_TARIFARIO_DESTINO IN (
		712 312 306 839 1441 309 97 792 240 18 599 594 595 1393 834 311 1414 14 792 851 226 1276 596 12 907 184 1016 851 838 1084 311 11 306 963 712 851 837 850 836 620 427 601 20 87 184
		   )
  AND  ( DW_D_SUBRUTA.ID_SUBRUTA=DW_F_INTERCONEXION.ID_SUBRUTA  )
  AND  (
  DW_D_TIEMPO_DIA.ID_DIA  BETWEEN  "&date1.:00:00:00"dt AND "&date2.:00:00:00"dt
  AND  DW_D_SENTIDO.DES_SENTIDO  =  'RECU PAR MEDITEL'
  AND  DW_D_LINEA.DES_CONT_PREP  =  'PREPAYE'
  AND  DW_D_SUBRUTA.DES_RUTA  IN  ('INTERNATIONAL', 'NATIONAL MC', 'NATIONAL', 'INTERNATIONAL DEDIE', 'INTERNATIONAL WANA')
  )
GROUP BY
  DW_F_INTERCONEXION.TELEFONO_DESTINO, 
  DW_D_TIEMPO_DIA.SEMANA 
ORDER BY   DW_F_INTERCONEXION.TELEFONO_DESTINO, 
  DW_D_TIEMPO_DIA.SEMANA ;

  quit; 

  %mend;


/****************************************************************************************************************************/
/******************************************************Appel fonctions*******************************************************/
/****************************************************************************************************************************/



%SCRIPT_MACROS; /* Calcule : FS1 LS1...4  S1...S4 */



/*Recharge*/
%recharge_querry(date1=&FS1,date2=&LS1); /*Semaine par Semaine*/
%recharge_querry(date1=&FS2,date2=&LS2);
%recharge_querry(date1=&FS3,date2=&LS3);
%recharge_querry(date1=&FS4,date2=&LS4);
/*Traffic Out*/
%traf_out(date=&LS1);/*Retour automatique*/
%traf_out(date=&LS2);
%traf_out(date=&LS3);
%traf_out(date=&LS4);
/*Traffic In*/
 %traf_in(date1=&FS1,date2=&LS4); /*inlure la p�riode totale*/


/****************************************************************************************************************************/
/* Groupement des tables */
data work.Recharge_pass_sem ; set Recharge_pass_:;
run ;



data WORK.BLOC_TRAF_OUT_SEM ; set V_TRAF_OUT_: ;
run ;



data work.BLOC_TRAF_IN_SEM  ; 
merge temp1 temp2 temp3;
by COD_LINEA SEMANA ;
SEMAINE = compress(SEMANA);
drop SEMANA;
run ;

proc datasets library=WORK;
Delete temp1;
Delete temp2;
Delete temp3;
run;


/********************CROISEMENT DES TABLES ET Renomation des semaines********/
proc sort data=BLOC_TRAF_IN_SEM out=HEB.BLOC_TRAF_IN_SEM nodupkey;
by COD_LINEA SEMAINE;
run;
proc sort data=Recharge_pass_sem out=HEB.Recharge_pass_sem nodupkey;
by COD_LINEA SEMAINE;
run;
proc sort data=BLOC_TRAF_OUT_SEM out=HEB.BLOC_TRAF_OUT_SEM nodupkey;
by COD_LINEA SEMAINE;
run;


%macro trs_sem(numsem1= , numsem2= ,numsem3= ,numsem4=) ;
data HEB.Base_Globale;
merge HEB.Recharge_pass_sem(IN=A) HEB.BLOC_TRAF_OUT_SEM HEB.BLOC_TRAF_IN_SEM;
by COD_LINEA SEMAINE ;
IF A;
if SEMAINE="&numsem1" then SEMAINE="S1" ;
else if SEMAINE="&numsem2" then SEMAINE="S2" ;
else if SEMAINE="&numsem4" then SEMAINE="S4" ;
else if SEMAINE="&numsem3" then SEMAINE="S3" ;
else if SEMAINE="&numsem4" then SEMAINE="S4" ;
/****missed calculating a variable****/
Min_Onet = Min_OnNet_pop + Min_OnNet_prp;
run ;
%mend ;
/*CALL*/
%trs_sem(numsem1=&S1,numsem2=&S2,numsem3=&S3,numsem4=&S4) ;

proc datasets library=HEB;
Delete Recharge_pass_sem;
Delete BLOC_TRAF_OUT_SEM;
Delete BLOC_TRAF_IN_SEM;
run;
proc datasets library=WORK;
Delete Recharge_pass_:;
run;
proc datasets library=WORK;
Delete V_TRAF_OUT_:;
run;


/****************************************************************************************************************************/

/********************TRANSPOSITION et calcule COMPORTEMENTAL PAR SEMAINE******************/
%macro TRANSPO_CALCUL;

proc sort data=HEB.Base_Globale;
by COD_LINEA;
run;

proc contents data=HEB.Base_Globale out=temp ; run ;
data _null_ ; set temp(where=(NAME not in ("COD_LINEA" "SEMAINE")));
call symputx(compress("col"!!_n_),NAME) ;
call symputx("nb",_n_) ;
run ;
%macro trans(col=);
proc transpose data=HEB.Base_Globale out=&col.(drop=_name_) prefix =&col._ ;
by COD_LINEA;
var &col.;
id SEMAINE;
run;
%mend;
%do i=1 %to &nb ;
%trans(col=&&col&i);
%end ;
data HEB.T_Base_Globale;
merge %do i=1 %to &nb ; &&col&i %end;;
by COD_LINEA ;
run ;
/*************************************************/
proc sort data= HEB.T_Base_Globale ; by COD_LINEA ; run ;
/**/
proc contents data=HEB.Base_Globale out=temp ; run ;
data _null_ ; set temp(where=(NAME not in ("COD_LINEA" "SEMAINE")));
call symputx(compress("col"!!_n_),NAME) ;
call symputx("nb2",_n_) ;
run ;
%macro tendances(colm=);
MEAN_&colm. = mean (of &colm._S1 &colm._S2 &colm._S3 &colm._S4);
CV_&colm. = CV (of &colm._S1 &colm._S2 &colm._S3 &colm._S4);
STD_&colm. = STD (of &colm._S1 &colm._S2 &colm._S3 &colm._S4);
if (&colm._S1 = 0 or &colm._S1 =.) then ACTS1 = 0; else ACTS1=1;
if (&colm._S2 = 0 or &colm._S2 =.) then ACTS2 = 0; else ACTS2=1;
if (&colm._S3 = 0 or &colm._S3 =.) then ACTS3 = 0; else ACTS3=1;
if (&colm._S4 = 0 or &colm._S4 =.) then ACTS4 = 0; else ACTS4=1; 
NB_SEM_&colm. = ACTS1+ACTS2+ACTS3+ACTS4;
drop ACTS1 ACTS2 ACTS3 ACTS4;
%mend;

data HEB.DMRT_Hebdo_PRP ; set HEB.T_BASE_GLOBALE;
%do i=1 %to &nb2 ;
%tendances(colm=&&col&i);
%end ;
run;

%mend ;

/*CALL*/
%TRANSPO_CALCUL;
/*
proc datasets library=HEB;
Delete Base_Globale;
Delete T_BASE_GLOBALE;
run;
*/
proc datasets lib=work kill nolist memtype=data;
quit;


/****************************************************************************************************************************/
/****************************************************SCORING MACRO***********************************************************/

%macro SCORE(base=);
data HEB.Scored(keep= COD_LINEA I_Y _WARN_ P_Y1 P_Y0 Q_Y1 Q_Y0 U_Y MEAN_MMPR) ; set &base ;
****************************************************************;
******             DECISION TREE SCORING CODE             ******;
****************************************************************;
******         LENGTHS OF NEW CHARACTER VARIABLES         ******;
LENGTH I_Y  $   12; 
LENGTH _WARN_  $    4; 
******              LABELS FOR NEW VARIABLES              ******;
LABEL P_Y1  = 'Predicted: Y=1' ;
      P_Y1  = 0;
LABEL P_Y0  = 'Predicted: Y=0' ;
      P_Y0  = 0;
LABEL Q_Y1  = 'Unadjusted P: Y=1' ;
      Q_Y1  = 0;
LABEL Q_Y0  = 'Unadjusted P: Y=0' ;
      Q_Y0  = 0;
LABEL I_Y  = 'Into: Y' ;
LABEL U_Y  = 'Unnormalized Into: Y' ;
LABEL _WARN_  = 'Warnings' ;
******      TEMPORARY VARIABLES FOR FORMATTED VALUES      ******;
LENGTH _ARBFMT_12 $     12; DROP _ARBFMT_12; 
_ARBFMT_12 = ' '; /* Initialize to avoid warning. */


DROP _ARB_F_;
DROP _ARB_BADF_;
     _ARB_F_ = -0.014501016;
     _ARB_BADF_ = 0;
******             ASSIGN OBSERVATION TO NODE             ******;
DROP _ARB_P_;
_ARB_P_ = 0;
DROP _ARB_PPATH_; _ARB_PPATH_ = 1;

********** LEAF     1  NODE   288 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

   DROP _BRANCH_;
  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_TOT_S1 ) AND 
      MOU_TOT_S1  <     4.86666666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_TOT_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0396660973;
      END;
    END;
  END;

********** LEAF     2  NODE   289 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_TOT_S1 ) AND 
          4.86666666666666 <= MOU_TOT_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0082017244;
      END;
    END;
  END;

********** LEAF     3  NODE   290 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
      MEAN_NB_RECH  <                1.875 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_RECH  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.037931577;
      END;
    END;
  END;

********** LEAF     4  NODE   291 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
                     1.875 <= MEAN_NB_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.071450306;
      END;
    END;
  END;

********** LEAF     5  NODE   295 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
      Nb_app_OffNet_S1  <                  1.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( Nb_app_OffNet_S1  ) THEN _BRANCH_ = 1;
   END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0400028419;
      END;
    END;
  END;

********** LEAF     6  NODE   296 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
                       1.5 <= Nb_app_OffNet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0080724526;
      END;
    END;
  END;

********** LEAF     7  NODE   297 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
      MEAN_NB_J_ACT_OUT  <     5.41666666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.039967293;
      END;
    END;
  END;

********** LEAF     8  NODE   298 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
          5.41666666666666 <= MEAN_NB_J_ACT_OUT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_J_ACT_OUT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.066378819;
      END;
    END;
  END;

********** LEAF     9  NODE   302 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
      MEAN_Nb_app_tot  <                7.875 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0432703826;
      END;
    END;
  END;

********** LEAF    10  NODE   303 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
                     7.875 <= MEAN_Nb_app_tot  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_tot  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.014467104;
      END;
    END;
  END;

********** LEAF    11  NODE   304 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
      MEAN_NB_J_ACT_OUT  <     5.41666666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.033123747;
      END;
    END;
  END;

********** LEAF    12  NODE   305 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
          5.41666666666666 <= MEAN_NB_J_ACT_OUT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_J_ACT_OUT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.061749546;
      END;
    END;
  END;

********** LEAF    13  NODE   309 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
      NB_SEM_CA_RECH  <                  1.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0315879528;
      END;
    END;
  END;

********** LEAF    14  NODE   310 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                       1.5 <= NB_SEM_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0042651748;
      END;
    END;
  END;

********** LEAF    15  NODE   311 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
      MEAN_CA_RECH  <     18.2916666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.031058145;
      END;
    END;
  END;

********** LEAF    16  NODE   312 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
          18.2916666666666 <= MEAN_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.057835123;
      END;
    END;
  END;

********** LEAF    17  NODE   316 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
      NB_SEM_CA_RECH  <                  1.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0288206999;
      END;
    END;
  END;

********** LEAF    18  NODE   317 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                       1.5 <= NB_SEM_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.004249781;
      END;
    END;
  END;

********** LEAF    19  NODE   315 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     3.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.055475064;
    END;
  END;

********** LEAF    20  NODE   321 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
      NB_SEM_DUREE_MOY_RECH  <                  0.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.023341277;
      END;
    END;
  END;

********** LEAF    21  NODE   322 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
                       0.5 <= NB_SEM_DUREE_MOY_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.012109023;
      END;
    END;
  END;

********** LEAF    22  NODE   320 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     3.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.055269545;
    END;
  END;

********** LEAF    23  NODE   326 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S1 ) AND 
      MOU_OffNet_S1  <     1.39166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_OffNet_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.023093359;
      END;
    END;
  END;

********** LEAF    24  NODE   327 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S1 ) AND 
          1.39166666666666 <= MOU_OffNet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.005118864;
      END;
   END;
  END;

********** LEAF    25  NODE   325 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
                     1.5 <= NB_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.041066306;
    END;
  END;

********** LEAF    26  NODE   331 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OffNet ) AND 
      MEAN_Nb_app_OffNet  <     5.70833333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0234122027;
      END;
    END;
  END;

********** LEAF    27  NODE   332 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OffNet ) AND 
          5.70833333333333 <= MEAN_Nb_app_OffNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_OffNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.000946928;
      END;
    END;
  END;

********** LEAF    28  NODE   330 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
                     1.5 <= NB_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.04035795;
    END;
  END;

********** LEAF    29  NODE   336 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Min_Onet_S1 ) AND 
      Min_Onet_S1  <                214.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( Min_Onet_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0193401014;
      END;
    END;
  END;

********** LEAF    30  NODE   337 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Min_Onet_S1 ) AND 
                     214.5 <= Min_Onet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.013455994;
      END;
    END;
  END;

********** LEAF    31  NODE   335 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     3.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.043170981;
    END;
  END;

********** LEAF    32  NODE   341 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Min_Onet_S1 ) AND 
      Min_Onet_S1  <                207.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( Min_Onet_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0177656007;
      END;
    END;
  END;

********** LEAF    33  NODE   342 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Min_Onet_S1 ) AND 
                     207.5 <= Min_Onet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.01192552;
      END;
    END;
  END;

********** LEAF    34  NODE   340 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     3.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.039757754;
    END;
  END;

********** LEAF    35  NODE   346 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
      Nb_app_OffNet_S1  <                  1.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( Nb_app_OffNet_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0210561728;
      END;
    END;
  END;

********** LEAF    36  NODE   347 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
                       1.5 <= Nb_app_OffNet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001678784;
      END;
    END;
  END;

********** LEAF    37  NODE   348 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_NB_J_ACT_OUT ) AND 
      CV_NB_J_ACT_OUT  <     22.0529001477353 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.040223907;
      END;
    END;
  END;

********** LEAF    38  NODE   349 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_NB_J_ACT_OUT ) AND 
          22.0529001477353 <= CV_NB_J_ACT_OUT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( CV_NB_J_ACT_OUT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.01617636;
      END;
    END;
  END;

********** LEAF    39  NODE   353 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
      MEAN_NB_J_ACT_OUT  <     4.29166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0201414918;
      END;
    END;
  END;

********** LEAF    40  NODE   354 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
          4.29166666666666 <= MEAN_NB_J_ACT_OUT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_J_ACT_OUT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.003781118;
      END;
    END;
  END;

********** LEAF    41  NODE   352 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
                     1.5 <= NB_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.032274973;
    END;
  END;

********** LEAF    42  NODE   358 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
      MEAN_Nb_app_tot  <                5.875 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0263685937;
      END;
    END;
  END;

********** LEAF    43  NODE   359 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  2.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
                     5.875 <= MEAN_Nb_app_tot  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_tot  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.005772104;
      END;
    END;
  END;

********** LEAF    44  NODE   360 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
      MEAN_NB_J_ACT_OUT  <     5.29166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.01386647;
      END;
    END;
  END;

********** LEAF    45  NODE   361 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     2.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_J_ACT_OUT ) AND 
          5.29166666666666 <= MEAN_NB_J_ACT_OUT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_J_ACT_OUT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.037220224;
      END;
    END;
  END;

********** LEAF    46  NODE   365 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CA_RECH_S1 ) AND 
    CA_RECH_S1  <                 14.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CA_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
      CV_Nb_app_OffNet  <     84.6902748443385 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.006336039;
      END;
    END;
  END;

********** LEAF    47  NODE   366 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CA_RECH_S1 ) AND 
    CA_RECH_S1  <                 14.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CA_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
          84.6902748443385 <= CV_Nb_app_OffNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( CV_Nb_app_OffNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0155956643;
      END;
    END;
  END;

********** LEAF    48  NODE   364 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CA_RECH_S1 ) AND 
                    14.5 <= CA_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.029034081;
    END;
  END;

********** LEAF    49  NODE   370 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
   IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
      MEAN_Nb_app_OnNet  <     3.58333333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0154183728;
      END;
    END;
  END;

********** LEAF    50  NODE   371 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
          3.58333333333333 <= MEAN_Nb_app_OnNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_OnNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001807482;
      END;
    END;
  END;

********** LEAF    51  NODE   369 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
                     1.5 <= NB_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.025910019;
    END;
  END;

********** LEAF    52  NODE   375 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
    NB_J_ACT_OUT_S1  <                  5.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_J_ACT_OUT_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
      MEAN_Nb_app_tot  <                5.875 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0204595286;
      END;
    END;
  END;

********** LEAF    53  NODE   376 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
    NB_J_ACT_OUT_S1  <                  5.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_J_ACT_OUT_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_tot ) AND 
                     5.875 <= MEAN_Nb_app_tot  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_tot  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0031302632;
      END;
    END;
  END;

********** LEAF    54  NODE   374 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
                     5.5 <= NB_J_ACT_OUT_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.026798052;
    END;
  END;

********** LEAF    55  NODE   380 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OnNet_S1 ) AND 
      MOU_OnNet_S1  <     1.28333333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_OnNet_S1  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0132487623;
      END;
    END;
  END;

********** LEAF    56  NODE   381 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
    NB_RECH_S1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OnNet_S1 ) AND 
          1.28333333333333 <= MOU_OnNet_S1  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.007580802;
      END;
    END;
  END;

********** LEAF    57  NODE   379 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_S1 ) AND 
                     1.5 <= NB_RECH_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.026668206;
    END;
  END;

********** LEAF    58  NODE   385 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH_DEAL ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
      NB_SEM_CA_RECH  <                  3.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.010724229;
      END;
    END;
  END;

********** LEAF    59  NODE   386 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH_DEAL ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                       3.5 <= NB_SEM_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.030795684;
      END;
    END;
  END;

********** LEAF    60  NODE   387 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( CV_CA_RECH_DEAL ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
      MEAN_NB_RECH  <                1.125 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0214443418;
      END;
    END;
  END;

********** LEAF    61  NODE   388 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( CV_CA_RECH_DEAL ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
                     1.125 <= MEAN_NB_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0008228909;
      END;
    END;
  END;

********** LEAF    62  NODE   392 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
    NB_J_ACT_OUT_S1  <                  5.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_J_ACT_OUT_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
      CV_Nb_app_OffNet  <     105.170687004676 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( CV_Nb_app_OffNet  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0052589997;
      END;
    END;
  END;

********** LEAF    63  NODE   393 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
    NB_J_ACT_OUT_S1  <                  5.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_J_ACT_OUT_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
          105.170687004676 <= CV_Nb_app_OffNet  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0215083659;
      END;
    END;
  END;

********** LEAF    64  NODE   391 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_J_ACT_OUT_S1 ) AND 
                     5.5 <= NB_J_ACT_OUT_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.021523306;
    END;
  END;

********** LEAF    65  NODE   397 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_MMPR ) AND 
    CV_MMPR  <     32.8305940026976 THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_MOU_TOT ) AND 
      CV_MOU_TOT  <     65.2390412520801 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.027091536;
      END;
    END;
  END;

********** LEAF    66  NODE   398 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_MMPR ) AND 
    CV_MMPR  <     32.8305940026976 THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(CV_MOU_TOT ) AND 
          65.2390412520801 <= CV_MOU_TOT  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( CV_MOU_TOT  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.008474515;
      END;
    END;
  END;

********** LEAF    67  NODE   399 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_MMPR ) AND 
        32.8305940026976 <= CV_MMPR  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_MMPR  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
      MEAN_Nb_app_OnNet  <     2.58333333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0159343222;
      END;
    END;
  END;

********** LEAF    68  NODE   400 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_MMPR ) AND 
        32.8305940026976 <= CV_MMPR  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_MMPR  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
          2.58333333333333 <= MEAN_Nb_app_OnNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_OnNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001253576;
      END;
    END;
  END;

********** LEAF    69  NODE   404 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CA_RECH_SCR_S1 ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
      MEAN_CA_RECH  <               11.125 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0022096174;
      END;
    END;
  END;

********** LEAF    70  NODE   405 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CA_RECH_SCR_S1 ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
                    11.125 <= MEAN_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.019893178;
      END;
    END;
  END;

********** LEAF    71  NODE   406 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( CA_RECH_SCR_S1 ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
      NB_SEM_CA_RECH  <                  0.5 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0018017632;
      END;
    END;
  END;

********** LEAF    72  NODE   407 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( CA_RECH_SCR_S1 ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                       0.5 <= NB_SEM_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0192906515;
      END;
    END;
  END;

********** LEAF    73  NODE   411 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
      MEAN_Nb_app_OnNet  <     3.58333333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0132881461;
      END;
    END;
  END;

********** LEAF    74  NODE   412 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OnNet ) AND 
          3.58333333333333 <= MEAN_Nb_app_OnNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_OnNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.003283634;
      END;
    END;
  END;

********** LEAF    75  NODE   410 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
                     1.5 <= NB_SEM_DUREE_MOY_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.023214189;
    END;
  END;

********** LEAF    76  NODE   416 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH_DEAL ) AND 
      MEAN_NB_RECH_DEAL  <     0.41666666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0130786535;
      END;
    END;
  END;

********** LEAF    77  NODE   417 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
    NB_SEM_CA_RECH  <                  3.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH_DEAL ) AND 
          0.41666666666666 <= MEAN_NB_RECH_DEAL  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_RECH_DEAL  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0012632215;
      END;
    END;
  END;

********** LEAF    78  NODE   415 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                     3.5 <= NB_SEM_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.026404007;
    END;
  END;

********** LEAF    79  NODE   421 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OnNet ) AND 
      MEAN_MOU_OnNet  <     0.05208333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.01664749;
      END;
    END;
  END;

********** LEAF    80  NODE   422 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OnNet ) AND 
          0.05208333333333 <= MEAN_MOU_OnNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_MOU_OnNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0007439269;
      END;
    END;
  END;

********** LEAF    81  NODE   420 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
                     1.5 <= NB_SEM_DUREE_MOY_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.02105689;
    END;
  END;

********** LEAF    82  NODE   426 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_Etoile1 ) AND 
    NB_SEM_Etoile1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_Etoile1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Min_Onet ) AND 
      MEAN_Min_Onet  <               110.25 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0172572737;
      END;
    END;
  END;

********** LEAF    83  NODE   427 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_Etoile1 ) AND 
    NB_SEM_Etoile1  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_Etoile1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Min_Onet ) AND 
                    110.25 <= MEAN_Min_Onet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Min_Onet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0018196369;
      END;
    END;
  END;

********** LEAF    84  NODE   425 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_Etoile1 ) AND 
                     1.5 <= NB_SEM_Etoile1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.020617663;
    END;
  END;

********** LEAF    85  NODE   431 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH ) AND 
    CV_CA_RECH  <     49.2762520384025 THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
      MEAN_CA_RECH  <               14.875 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.002287783;
      END;
    END;
  END;

********** LEAF    86  NODE   432 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH ) AND 
    CV_CA_RECH  <     49.2762520384025 THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
                    14.875 <= MEAN_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.024487649;
      END;
    END;
  END;

********** LEAF    87  NODE   433 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH ) AND 
        49.2762520384025 <= CV_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_CA_RECH  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
      MEAN_NB_RECH  <     1.41666666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0158831722;
      END;
    END;
  END;

********** LEAF    88  NODE   434 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_CA_RECH ) AND 
        49.2762520384025 <= CV_CA_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_CA_RECH  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
          1.41666666666666 <= MEAN_NB_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0001819741;
      END;
    END;
  END;

********** LEAF    89  NODE   438 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OnNet ) AND 
      MEAN_MOU_OnNet  <     2.55833333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0093102341;
      END;
    END;
  END;

********** LEAF    90  NODE   439 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
    NB_SEM_DUREE_MOY_RECH  <                  1.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_SEM_DUREE_MOY_RECH  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OnNet ) AND 
          2.55833333333333 <= MEAN_MOU_OnNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_MOU_OnNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.00168757;
      END;
    END;
  END;

********** LEAF    91  NODE   437 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_SEM_DUREE_MOY_RECH ) AND 
                     1.5 <= NB_SEM_DUREE_MOY_RECH  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.021615208;
    END;
  END;

********** LEAF    92  NODE   443 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OnNet_S1 ) AND 
    Nb_app_OnNet_S1  <                  8.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Nb_app_OnNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S4 ) AND 
      MOU_OffNet_S4  <     1.19166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0122093835;
      END;
    END;
  END;

********** LEAF    93  NODE   444 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OnNet_S1 ) AND 
    Nb_app_OnNet_S1  <                  8.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Nb_app_OnNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S4 ) AND 
          1.19166666666666 <= MOU_OffNet_S4  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_OffNet_S4  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001577714;
      END;
    END;
  END;

********** LEAF    94  NODE   442 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OnNet_S1 ) AND 
                     8.5 <= Nb_app_OnNet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.016656117;
    END;
  END;

********** LEAF    95  NODE   448 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(PCT_NB_RECH_DEAL_S1 ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OnNet_S3 ) AND 
      MOU_OnNet_S3  <     0.69166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_OnNet_S3  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.002348125;
      END;
    END;
  END;

********** LEAF    96  NODE   449 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(PCT_NB_RECH_DEAL_S1 ) THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OnNet_S3 ) AND 
          0.69166666666666 <= MOU_OnNet_S3  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.02196948;
      END;
    END;
  END;

********** LEAF    97  NODE   450 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( PCT_NB_RECH_DEAL_S1 ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
      NB_SEM_CA_RECH  <                  0.5 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.000733518;
      END;
    END;
  END;

********** LEAF    98  NODE   451 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 
  _BRANCH_ = -1;
  IF MISSING( PCT_NB_RECH_DEAL_S1 ) THEN _BRANCH_ = 2;

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(NB_SEM_CA_RECH ) AND 
                       0.5 <= NB_SEM_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( NB_SEM_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0160842388;
      END;
    END;
  END;

********** LEAF    99  NODE   455 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(MOU_OffNet_S1 ) AND 
    MOU_OffNet_S1  <     0.34166666666666 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( MOU_OffNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OffNet ) AND 
      MEAN_MOU_OffNet  <     0.23541666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_MOU_OffNet  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0023634839;
      END;
    END;
  END;

********** LEAF   100  NODE   456 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(MOU_OffNet_S1 ) AND 
    MOU_OffNet_S1  <     0.34166666666666 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( MOU_OffNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_OffNet ) AND 
          0.23541666666666 <= MEAN_MOU_OffNet  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0180117292;
      END;
    END;
  END;

********** LEAF   101  NODE   457 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(MOU_OffNet_S1 ) AND 
        0.34166666666666 <= MOU_OffNet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
      MEAN_CA_RECH  <     11.5833333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0014410695;
      END;
    END;
  END;

********** LEAF   102  NODE   458 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(MOU_OffNet_S1 ) AND 
        0.34166666666666 <= MOU_OffNet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH ) AND 
          11.5833333333333 <= MEAN_CA_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_CA_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.012625797;
      END;
    END;
  END;

********** LEAF   103  NODE   462 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_TR2_S1 ) AND 
    NB_RECH_TR2_S1  <                  0.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_TR2_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
      MEAN_NB_RECH  <                1.125 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0129106943;
      END;
    END;
  END;

********** LEAF   104  NODE   463 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_TR2_S1 ) AND 
    NB_RECH_TR2_S1  <                  0.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( NB_RECH_TR2_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_NB_RECH ) AND 
                     1.125 <= MEAN_NB_RECH  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_NB_RECH  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.00131453;
      END;
    END;
  END;

********** LEAF   105  NODE   461 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(NB_RECH_TR2_S1 ) AND 
                     0.5 <= NB_RECH_TR2_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.017634263;
    END;
  END;

********** LEAF   106  NODE   467 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
    Nb_app_OffNet_S1  <                  6.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Nb_app_OffNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_TOT ) AND 
      MEAN_MOU_TOT  <     7.22916666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_MOU_TOT  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0009158725;
      END;
    END;
  END;

********** LEAF   107  NODE   468 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
    Nb_app_OffNet_S1  <                  6.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Nb_app_OffNet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_MOU_TOT ) AND 
          7.22916666666666 <= MEAN_MOU_TOT  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0151188407;
      END;
    END;
  END;

********** LEAF   108  NODE   466 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Nb_app_OffNet_S1 ) AND 
                     6.5 <= Nb_app_OffNet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.012201923;
    END;
  END;

********** LEAF   109  NODE   472 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
    CV_Nb_app_OffNet  <     105.948034810282 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_Nb_app_OffNet  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Min_Onet ) AND 
      MEAN_Min_Onet  <                150.5 THEN DO;
       _BRANCH_ =    1; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Min_Onet  ) THEN _BRANCH_ = 1;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0027497241;
      END;
    END;
  END;

********** LEAF   110  NODE   473 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
    CV_Nb_app_OffNet  <     105.948034810282 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_Nb_app_OffNet  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Min_Onet ) AND 
                     150.5 <= MEAN_Min_Onet  THEN DO;
       _BRANCH_ =    2; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.014077022;
      END;
    END;
  END;

********** LEAF   111  NODE   471 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_Nb_app_OffNet ) AND 
        105.948034810282 <= CV_Nb_app_OffNet  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + 0.0125871072;
    END;
  END;

********** LEAF   112  NODE   475 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_PCT_NB_TR2 ) AND 
    CV_PCT_NB_TR2  <     86.7820902993753 THEN DO;
     _BRANCH_ =    1; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;
     _ARB_F_ + -0.016299268;
    END;
  END;

********** LEAF   113  NODE   477 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_PCT_NB_TR2 ) AND 
        86.7820902993753 <= CV_PCT_NB_TR2  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_PCT_NB_TR2  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH_DEAL ) AND 
      MEAN_CA_RECH_DEAL  <     1.45833333333333 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0112443576;
      END;
    END;
  END;

********** LEAF   114  NODE   478 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(CV_PCT_NB_TR2 ) AND 
        86.7820902993753 <= CV_PCT_NB_TR2  THEN DO;
     _BRANCH_ =    2; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( CV_PCT_NB_TR2  ) THEN _BRANCH_ = 2;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_CA_RECH_DEAL ) AND 
          1.45833333333333 <= MEAN_CA_RECH_DEAL  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_CA_RECH_DEAL  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001015132;
      END;
    END;
  END;

********** LEAF   115  NODE   482 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Min_Onet_S1 ) AND 
    Min_Onet_S1  <                117.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Min_Onet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OffNet ) AND 
      MEAN_Nb_app_OffNet  <     2.29166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0134237922;
      END;
    END;
  END;

********** LEAF   116  NODE   483 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Min_Onet_S1 ) AND 
    Min_Onet_S1  <                117.5 THEN DO;
     _BRANCH_ =    1; 
    END; 
  IF _BRANCH_ LT 0 THEN DO; 
     IF MISSING( Min_Onet_S1  ) THEN _BRANCH_ = 1;
  END; 
  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MEAN_Nb_app_OffNet ) AND 
          2.29166666666666 <= MEAN_Nb_app_OffNet  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MEAN_Nb_app_OffNet  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + 0.0012933767;
      END;
    END;
  END;

********** LEAF   117  NODE   484 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Min_Onet_S1 ) AND 
                   117.5 <= Min_Onet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S2 ) AND 
      MOU_OffNet_S2  <     6.74166666666666 THEN DO;
       _BRANCH_ =    1; 
      END; 

    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.001161185;
      END;
    END;
  END;

********** LEAF   118  NODE   485 ***************;
IF _ARB_BADF_ EQ 0 THEN DO; 

  _BRANCH_ = -1;
    IF  NOT MISSING(Min_Onet_S1 ) AND 
                   117.5 <= Min_Onet_S1  THEN DO;
     _BRANCH_ =    2; 
    END; 

  IF _BRANCH_ GT 0 THEN DO;

    _BRANCH_ = -1;
      IF  NOT MISSING(MOU_OffNet_S2 ) AND 
          6.74166666666666 <= MOU_OffNet_S2  THEN DO;
       _BRANCH_ =    2; 
      END; 
    IF _BRANCH_ LT 0 THEN DO; 
       IF MISSING( MOU_OffNet_S2  ) THEN _BRANCH_ = 2;
    END; 
    IF _BRANCH_ GT 0 THEN DO;
       _ARB_F_ + -0.017599392;
      END;
    END;
  END;

_ARB_F_ = 2.0 * _ARB_F_;
IF _ARB_BADF_ NE 0 THEN P_Y0  = 0.49275;
ELSE IF _ARB_F_ > 45.0 THEN P_Y0  = 1.0;
ELSE IF _ARB_F_ < -45.0 THEN P_Y0  = 0.0;
ELSE P_Y0  = 1.0/(1.0 + EXP( - _ARB_F_));
P_Y1  = 1.0 - P_Y0 ;
*****  CREATE Q_: POSTERIORS WITHOUT PRIORS ****;
Q_Y1  = P_Y1 ;
Q_Y0  = P_Y0 ;

*****  I_ AND U_ VARIABLES *******************;
DROP _ARB_I_ _ARB_IP_;
_ARB_IP_ = -1.0;
IF _ARB_IP_ + 1.0/32768.0 < P_Y1 THEN DO;
   _ARB_IP_ = P_Y1 ;
   _ARB_I_  = 1;
   END;
IF _ARB_IP_ + 1.0/32768.0 < P_Y0 THEN DO;
   _ARB_IP_ = P_Y0 ;
   _ARB_I_  = 2;
   END;
SELECT( _ARB_I_);
  WHEN( 1) DO;
    I_Y  = '1' ;
    U_Y  =  1;
     END;
  WHEN( 2) DO;
    I_Y  = '0' ;
    U_Y  =  0;
     END;
   END;

****************************************************************;
******          END OF DECISION TREE SCORING CODE         ******;
****************************************************************;
run ;
%mend;
/***********************************************************************APPEL AU SCORE*****************************************************/


%SCORE(base=HEB.DMRT_Hebdo_PRP);

/***********************************************************************Defining Target*****************************************************/
data HEB.TARGET(KEEP=COD_LINEA U_Y MEAN_MMPR );
set HEB.SCORED(where=(P_Y1>=0.75 OR P_Y1<0.3 ));
run;



/*
PROC RANK DATA = HEB.SCORED
	GROUPS=10
	TIES=MEAN
	OUT=HEB.Target;
	VAR P_Y0;
RANKS RANG ;
RUN; 

Data HEB.Churners(where=(RANG IN (9 8)) keep=(COD_LINEA U_Y MEAN_MMPR));
set HEB.Target;
run;

Data HEB.Upsale(where=(RANG IN (0 1)) keep=(COD_LINEA U_Y MEAN_MMPR));
set HEB.Target;
run;*/


PROC SQL;
   CREATE TABLE WORK.Target_qualified AS 
   SELECT DISTINCT t1.COD_LINEA, 
          t1.U_Y, 
          t1.MEAN_MMPR, 
          t2.MEAN_Etoile3, 
          t2.MEAN_Etoile1
      FROM HEB.TARGET t1 INNER JOIN HEB.DMRT_HEBDO_PRP t2 ON (t1.COD_LINEA = t2.COD_LINEA)
      WHERE t1.U_Y = 0;
QUIT;

