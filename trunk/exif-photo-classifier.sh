#!/bin/bash
# $Id$

# pour chaque fichier, le comparer aux signatures de
# fichiers déjà présent dans le répertoire de destination, puis :
# ATTENTION : quoi faire avec les fichiers connexes ? [Picasa.ini, *.MPG, *.THM etc...]

STARTGLOBAL=$(date +%s.%N)

nbrFichierTraites=0;
SRC=$1

SSDEEP=/usr/local/bin/ssdeep
[ ! -x "${SSDEEP}" ] && echo "ERREUR : ${SSDEEP} n'esxiste pas" && exit;

detox -r -v -s utf_8 "${SRC}"
detox -r -v -s lower "${SRC}"





########################################################################
# fonctions
########################################################################
function effacer {

	 echo "INFO  : effacer";
	 if [ $? -ne 0 ]; then
		  echo
		  echo "Directory does not exists"
		  echo "Please try again."
		  echo
		  exit 0
	 fi
	 return 1
}



function deplacer {

	 echo "INFO  : deplacer";
	 if [ $? -ne 0 ]; then
		  echo
		  echo "Directory does not exists"
		  echo "Please try again."
		  echo
		  exit 0
	 fi
	 return 1
}



function copier {

	 echo "INFO  : copier";
	 if [ $? -ne 0 ]; then
		  echo
		  echo "Directory does not exists"
		  echo "Please try again."
		  echo
		  exit 0
	 fi
	 return 1
}



function renommer {

	 echo "INFO  : renommer";
	 if [ $? -ne 0 ]; then
		  echo
		  echo "Directory does not exists"
		  echo "Please try again."
		  echo
		  exit 0
	 fi
	 return 1
}


function signatures_md5_sont_identiques {

	 fichier_1=(`md5sum ${1}  2>/dev/null | cut -c1-32 `)
	 fichier_2=(`md5sum ${2}  2>/dev/null | cut -c1-32 `)


	 echo "INFO  : signatures_md5_sont_identiques()  : debut traitement de $1 et $2";

	 if [ "${fichier_1}" == "${fichier_2}" ]
	 then
		  return 1;
	 else
		  return 0;
	 fi
}



function signatures_SSD_sont_identiques {

	 fichier_1=${1}
	 fichier_2=${2}

	 echo "INFO  : signatures_SSD_sont_identiques()  : debut traitement de $1 et $2";

	 ssdeep -s -b ${fichier_1} > /tmp/sig.txt

	 ssdeepres=(`ssdeep -bm /tmp/sig.txt ${fichier_2} | sed -r "s/.*\(([0-9]*)\)/\\1/"`)

    if(( ssdeepres > 98 )) # [ $ssdeepres -gt 98 ]
	 then
		  return 0
	 else
		  return 0
	 fi

}




function noms_de_fichier_sont_identiques {

	 fichier_1=(`basename ${1}`)
	 fichier_2=(`basename ${2}`)


	 echo "INFO  : noms_de_fichier_sont_identiques() : debut traitement de $fichier_1 $fichier_2";

	 if [ "${fichier_1}" == "${fichier_2}" ]
	 then
		  return 1;
	 else
		  return 0
	 fi
}









########################################################################
# code principal
########################################################################



for DIR in `find "${SRC}" -type d -depth -print 2> /dev/null`;
# -depth = :
#./2007/12/15
#./2007/12
#./2007
do
    # traitement sur les fichiers trouve ds le repertoire $DIR

    # on met les fichiers du rep DIR dans un tableau
    arrRepertoire=( ` ls  "${DIR}" ` ) ;

    # on extrait le mombre d'element du tableau
    len=${#arrRepertoire[*]}


    # on boucle sur les elements du tableau
    #  - traitement sur chacun des fichiers (md5, ssdeep; extraction exiftool de J,M,A;
	 #    deplacement vers DEST etc)
    #  - creation structure repertoire AAAA/MM/JJ
    #  - traitement fichier autres que photos : .THM, .MPG, picasa.ini, .db etc.

    i=0
    while [ $i -lt $len ]; do

	     # memorisation du rep/nom du fichier en traitement
		  fichierEnTraitement="./${DIR}/${arrRepertoire[$i]}";

        # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink,
		  # puis si oui, on commence le traitement
        if [[ -f  "${fichierEnTraitement}"  &&
						  "${fichierEnTraitement}" != "./${DIR}/Thumbs.db" &&
						  "${fichierEnTraitement}" != "./${DIR}/thumbs.db" ]]
        then

	         # debut d'une section de chronometrage
				STARTFICHIER=$(date +%s.%N)

	         # debut d'une section de chronometrage
				START=$(date +%s.%N)


            # ce tableau (arrTS) contient tout les timestamps dispo [ soit CreateDate,
				# DateTimeOriginal, FileModifyDate et stat etc.]
	         # vu que les timestamps sont inserer dans le tableau dans l'ordre adcendant,
				# l'element [0] contient le timestamp le plus ancien et qui
     	      # correspond probablement a la date de prise de la photo [CreateDate].
				# Exception possible : erreur quelconque qui fait que [0]
	         # pourrait contenir 1janvier1970. Les autres elements [1],[2] etc. contiennent
	         # des timestamps plus recents [DateTimeOriginal] [FileModifyDate] et [stat %Y]
       	   # donc on commence avec ${arrTS[0]} si il existe et ensuite on
				# descend vers ${arrTS[1]} ${arrTS[2]} etc

 	         # pour commencer on affecte a notre tableau arrTS les timestamps EXIF
				# trouve avec soit jhead soit exiftool
				if [ "${2}" == "1" ] # si le 2e param est 1, on utilise exiftool, sinon jhead
				then
					 arrTS=(`exiftool -e --fast -CreateDate -DateTimeOriginal -FileModifyDate \
					      -S -d "%s" ${fichierEnTraitement}  | \
                    sed -r "s/.*: ([0-9:]*).*/\1/"`);
					 echo "INFO  : traitement exiftooljhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
				else
					 jheadTS=(`jhead -q  ${fichierEnTraitement} 2>/dev/null| grep "Date/Time" | \
					           sed -r "s/.*: ([0-9:]*).*/\1/" | tr -d ':' `)
					 arrTS=(`date -d ${jheadTS} +%s 2>/dev/null`);
					 echo "INFO  : traitement jhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
				fi

            # debut d'une section de chronometrage
				START=$(date +%s.%N)


	         # ensuite si necess (c.a.d. le tableau arrTS n'as pas ete remplie par
				# exiftool/jhead et est donc vide) et
	         # en dernier recours, on affecte le timestamp du fichier lui-meme
				if [ "${#arrTS[*]}" == "0" ]
				then
		          # on utilise 'stat' pour extraire le %Y = 'Time of last modification as
					 # seconds since Epoch'
					 echo "INFO  : pas de date EXIF, on utilise 'stat'...";
					 StatTS=(`stat --format='%Y'  ${fichierEnTraitement}  `);
		          # on ajoute ce timestamp a notre tableau
					 arrTS[${#arrTS[*]}]=$StatTS;
					 echo "INFO  : traitement stat : $(echo "$(date +%s.%N) - $START" | bc) secondes";
				fi




	         # Ici on transforme ces timestmaps en un tableau arrNouvRep[] 0=AAAA 1=MM 2=JJ
	         # qui sera utilise pour assemble l;e rep de DESTination
				if [ "${#arrTS[*]}" != "0" ] # verif que le tableau est pas vide avant de s'en servir
				then
       			 arrNouvRep=( `date +'%Y %m %d' -d @${arrTS[0]}` );

                # assemblage du repertoire de destination qui sera utilise pour deplacer les fichiers
					 DEST=${arrNouvRep[0]}/${arrNouvRep[1]}/${arrNouvRep[2]};

                # debut d'une section de chronometrage
					 START=$(date +%s.%N)

     	          # on cree le repertoire DEST
					 if [ ! -d "${DEST}" ]; then
						  mkdir -p ${DEST} ;
					 fi
					 echo "INFO  : traitement mkdir ${DEST} : $(echo "$(date +%s.%N) - $START" | bc) secondes";
				else
					 echo "ERREUR : pas de timestamp pour : ${fichierEnTraitement} ... fin du programme.";
                exit;
            fi





	         # info pour debug : ls et md5sum du fichier pre deplacement
				md5FichierenTraitement=`md5sum ${fichierEnTraitement}  2>/dev/null | cut -c1-32 `
				echo "INFO  : on s'apprete a copie/deplace ceci : [$md5FichierenTraitement] " \
				              `ls -al ${fichierEnTraitement} 2>/dev/null`

	         # et on s'apprete a copier par dessus :
				md5FichierExistant=`md5sum ./${DEST}/${arrRepertoire[$i]}  2>/dev/null | cut -c1-32 `
				echo "INFO  : sur ceci : [$md5FichierExistant] " `ls -al ./${DEST}/${arrRepertoire[$i]} \
				              2>/dev/null`



				signatures_md5_sont_identiques ${fichierEnTraitement} ./${DEST}/${arrRepertoire[$i]}
				md5retcode=$?

				if [ "$md5retcode" == "1" ]
				then
					 # effacer ou ignorer fichier source, car md5 identique = fichiers identiques
					 effacer  ${fichierEnTraitement}

				elif [ "$md5retcode" == "0" ]
				then
					 # sig md5 sont differentes, on va test plus loin avec ssdeep
					 signatures_SSD_sont_identiques  ${fichierEnTraitement} \
					            ./${DEST}/${arrRepertoire[$i]}
					 ssdretcode=$?

					 if [ "$ssdretcode" == "1" ]
					 then
					     # effacer ou ignorer fichier source, car ssdeep identique = fichiers identiques
						  effacer  ${fichierEnTraitement}

					 elif [ "$ssdretcode" == "0" ]
					 then
						  # sig ssdeep sont differentes, on va test plus loin avec les noms de fichiers
						  noms_de_fichier_sont_identiques  ${fichierEnTraitement} \
						             ./${DEST}/${arrRepertoire[$i]}
						  nomretcode=$?

						  if [ "$nomretcode" == "1" ]
						  then
								renommer  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
								copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
								if [ "${param-move}" == "0" ]
								then
									 effacer  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
								fi
						  elif [ "$nomretcode" == "0" ]
						  then
								# noms de ficheirs sont differents
								copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
								if [ "${param-move}" == "0" ]
								then
									 effacer  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
								fi
						  else
								# sig ssdeep sont egales
								echo "erreur ds noms_de_fichier_sont_identiques [$?]"
						  fi
					 else
						  # sig ssdeep sont egales
						  echo "erreur ds signatures_SSD_sont_identiques [$?]"
					 fi
				else
					 # erreur
					 echo "erreur ds signatures_md5_sont_identiques [$?]"
 				fi




# 		      # debut d'une section de chronometrage
# 				START=$(date +%s.%N)


# 		      # on deplace/copie le fichier ICI (si $3 vaut 1, on fait MV, sinon CP /; par defaut c'est donc CP)
# 		      # exif-photo-classifier.sh src 0 1
# 				if [ "${3}" == "1" ]
# 				then
# 					 mv ${fichierEnTraitement} ${DEST}
# 					 echo "INFO  : deplacement de : ${fichierEnTraitement} vers : ${DEST} : \
#                              $(echo "$(date +%s.%N) - $START" | bc) secondes";
# 				else
# 					 cp  --backup=numbered --preserve=all ${fichierEnTraitement} ${DEST}
# 					 echo "INFO  : copie de : ${fichierEnTraitement} vers : \
#                             ${DEST} : $(echo "$(date +%s.%N) - $START" | bc) secondes";
# 				fi




	         # compteur de fichier traites
				let nbrFichierTraites++

		      # info pour debug : ls du fichier post deplacement
				echo -n "INFO  :       dans ${DEST} : [$md5FichierExistant] " `ls -al ./${DEST}/${arrRepertoire[$i]}`
				echo "";
				echo "INFO  : traitement de ${fichierEnTraitement} : $(echo "$(date +%s.%N) - $STARTFICHIER"\
				               | bc) secondes";echo "";echo "";


		  else
	         # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink
				echo "INFO  : il s'agit bien d'un repertoire ou symlink, on passe au prochain...";
		  fi



		  let i++
    done
done



# output d'info/debug
echo "INFO  : ${nbrFichierTraites} fichiers ont ete copier/deplacer.";
echo "INFO  : traitement TOTAL : $(echo "$(date +%s.%N) - $STARTGLOBAL" | bc) secondes";



exit;




#if signatures_md5_sont_identiques() {
# 		  effacer()
#     }
#     else{
# 		  if signatures_SSD_sont_identiques() {
# 					 effacer()
# 				}
# 				else{
# 					 if noms_de_fichier_sont_identiques() {
# 								renommer()
# 								copier()
# 								effacer()
# 						  }
# 						  else{
# 								copier()
# 								effacer()
# 						  }
# 				}
#     }
