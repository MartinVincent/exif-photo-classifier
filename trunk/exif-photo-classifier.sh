#!/bin/bash
# pour chaque fichier, le comparer aux signatures de 
# fichiers déjà présent dans le répertoire de destination, puis :
# ATTENTION : quoi faire avec les fichiers connexes ? [Picasa.ini, *.MPG, *.THM etc...]

STARTGLOBAL=$(date +%s.%N)

nbrFichierTraites=0;
SRC=$1


detox -r -v -s utf_8 "${SRC}"
detox -r -v -s lower "${SRC}"


 
for DIR in `find "${SRC}" -type d -depth -print 2> /dev/null`;
# -depth = :
#./2007/12/15
#./2007/12
#./2007
do
    # traitement sur les fichiers trouvé ds le répertoire $DIR
    #echo "INFO  : debut de la boucle sur les repertoires du tableau : on traite le rep : $DIR ...";

    # on met les fichiers du rep DIR dans un tableau
    arrRepertoire=( ` ls  "${DIR}" ` ) ;
 
    # on extrait le mombre d'element du tableau
    len=${#arrRepertoire[*]}
 
    # echo "The array for '"${DIR}"' has $len members. They are:"
    # echo ${arrRepertoire[@]}

    
    # on boucle sur les elements du tableau
    i=0
    while [ $i -lt $len ]; do

	fichierEnTraitement="./${DIR}/${arrRepertoire[$i]}" ;
	#echo "INFO  : debut de la boucle sur les ELEMENTS du tableau : ${fichierEnTraitement}";
        # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink
        if [[ -f  "${fichierEnTraitement}"  &&  "${fichierEnTraitement}" != "./${DIR}/Thumbs.db" &&  "${fichierEnTraitement}" != "./${DIR}/thumbs.db" ]]
        then

		STARTFICHIER=$(date +%s.%N)
                #  - traitement sur chacun des fichiers (md5, ssdeep; extraction exiftool de J,M,A; deplacement vers DEST etc)
                #  - creation structure repertoire AAAA/MM/JJ
                #  - traitement fichier autres que photos : .THM, .MPG, picasa.ini, .db etc. 
       		#echo "INFO  : debut du traitement de i=$i: ${fichierEnTraitement}";
 
		START=$(date +%s.%N)
		# pour commencer on affecte a notre tableau les timestamps EXIF trouve avec 'exiftool'
		if [ $2 ]
		then
			arrTS=(`exiftool -e --fast -CreateDate -DateTimeOriginal -FileModifyDate  -S -d "%s" ${fichierEnTraitement}  | \
                                    sed -r "s/.*: ([0-9:]*).*/\1/"`);
			echo "INFO  : traitement exiftooljhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
		else	
			jheadTS=(`jhead -q  ${fichierEnTraitement} 2>/dev/null| grep "Date/Time" | sed -r "s/.*: ([0-9:]*).*/\1/" | tr -d ':' `)
			arrTS=(`date -d ${jheadTS} +%s 2>/dev/null`);
			echo "INFO  : traitement jhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
		fi


		START=$(date +%s.%N)
		# ensuite si necess (c.a.d. le tableau est vide) et en dernier recours, on affecte le timestamp du fichier lui-meme
		if [ "${#arrTS[*]}" == "0" ]
		then
			# on utilise 'stat' pour extraire le %Y = 'Time of last modification as seconds since Epoch'
			echo "INFO  : pas de date EXIF, on utilise 'stat'...";
			StatTS=(`stat --format='%Y'  ${fichierEnTraitement}  `);
			# on ajoute ce timestamp a notre tableau
			arrTS[${#arrTS[*]}]=$StatTS;
			echo "INFO  : traitement stat : $(echo "$(date +%s.%N) - $START" | bc) secondes";
		fi	


	
 
       		# ce tableau contient tout les timestamps dispo [ soit CreateDate, DateTimeOriginal, FileModifyDate et stat ]
		# vu que les timestamps sont inserer dans le tableau and l'ordre adcendant, l'element [0] contient le timestamp le plus ancien et qui
		# correspond probablement a la date de prise de la photo [CreateDate]. Exception possible : erreur quelconque qui fait que [0] 
		# pourrait contenir 1janvier1970. Les autres elements [1],[2] etc. contiennent 
		# des timestamps plus recents [DateTimeOriginal] [FileModifyDate] et [stat %Y]
       		# 
		# Ici on transforme ces timestmaps en AAAA,MM,JJ
       		# donc on commence avec ${a[0]} si il existe et ensuite on descend vers ${a[1]} ${a[2]} etc
		if [ "${#arrTS[*]}" != "0" ] # verif que le tableau est pas vide avant de s'en servir	
		then
       			arrNouvRep=( `date +'%Y %m %d' -d @${arrTS[0]}` )
		else
			echo "ERREUR : pas de timestamp pour fichier : ${fichierEnTraitement} ... fin du programme.";
			exit;
		fi 
	

                # on memorise l'ancien emplacement d'origine du fichier, pour fin d'output de debug
		# echo "INFO  : le repertoire que l'on voudras cree : ${DEST} correspond a : `date -d @${a[0]}`";
		#logMessages=`ls -al ${fichierEnTraitement}` ;
 
                # ici , on pourrait tester avec MD5 ou ssdeep
 
                # on utilise exiftool pour deplacer les photos, c'est plus pratique avec la numerotion auto en cas de doublon
                # exiftool ne retourne 0 que si il a reussi a extraire des donnees EXIF...donc si il ret 1, c que ce n'est pas une photo
                # contenant des donnees EXIF OU ALORS que c'est Picasa.ini ou un MPG, THM, thumbs.db etc.
                #echo 'INFO  : exiftool  -P -r -d %Y/%m/%d/%f%+c.%%e "-filename<datetimeoriginal" -o dest/ ${fichierEnTraitement} ';
		#exiftool -q -P -r -d %Y/%m/%d/%f%+c.%%e "-filename<datetimeoriginal" -o dest/ ${fichierEnTraitement}  2>&1 ;
	        

                
		#on test sur $? : si '0', le fichier etait une image et est rendu ds ${DEST}
                #si '1' : c\'est soit un film, picasa.ini ou autre : on copie dans ${DEST}}  
		        
		#RETCODE=$?

                #if error ...:
              #  if [ $RETCODE -ne 0 ];
              #  then
                       # si '0', le fichier etait une image et est rendu ds DEST
		       #echo -n ""; #INFO  : '0', le fichier etait une image et est rendu ds ${DEST} ";
                       #else 
                       #si '1' : c\'est soit un film, picasa.ini ou autre : on copie dans 	${DEST}  
						
			echo "INFO  : on copie/deplace ceci :" `ls -al ${fichierEnTraitement}`
			#echo $logMessages;
			#emplacement d'origine du fichier, pour fin d'output de debug
			

			# assemblage du repertoire de destination qui sera utilise pour deplacer les fichiers
			DEST=${arrNouvRep[0]}/${arrNouvRep[1]}/${arrNouvRep[2]};
			START=$(date +%s.%N)
			# on cree le repertoire DEST et 					
			if [ ! -d "${DEST}" ]; then
				#echo "INFO  : creation de ${DEST}...>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
				mkdir -p ${DEST} ;
			fi
			echo "INFO  : traitement mkdir : $(echo "$(date +%s.%N) - $START" | bc) secondes";

			START=$(date +%s.%N)
			cp  --backup=numbered --preserve=all ${fichierEnTraitement} ${DEST}

			#mv ${fichierEnTraitement} ${DEST}
			echo "INFO  : traitement cp/mv : $(echo "$(date +%s.%N) - $START" | bc) secondes";
			let nbrFichierTraites++
			echo -n "INFO  :       dans ${DEST} :" `ls -al ./${DEST}/${arrRepertoire[$i]}`
			echo "";
			echo "INFO  : traitement de ${fichierEnTraitement} : $(echo "$(date +%s.%N) - $STARTFICHIER" | bc) secondes";

			echo "";echo "";
               # fi

        fi



	let i++
    done
done
 
 
 
echo "INFO  : ${nbrFichierTraites} fichiers ont ete copier/deplacer.";

echo "INFO  : traitement TOTAL : $(echo "$(date +%s.%N) - $STARTGLOBAL" | bc) secondes";




exit; 
 
 
 
 
 
if signatures_md5_sont_identiques() {
	effacer()
}
else{
	if signatures_SSD_sont_identiques() {
		effacer()
	}
	else{
		if noms_de_fichier_sont_identiques() {
			renommer()
			copier()
			effacer()
		}
		else{
			copier()
			effacer()
		}
	}
}
