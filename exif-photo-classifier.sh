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
    # traitement sur les fichiers trouve ds le repertoire $DIR

    # on met les fichiers du rep DIR dans un tableau
    arrRepertoire=( ` ls  "${DIR}" ` ) ;
    
    # on extrait le mombre d'element du tableau
    len=${#arrRepertoire[*]}
    
    
    # on boucle sur les elements du tableau
    #  - traitement sur chacun des fichiers (md5, ssdeep; extraction exiftool de J,M,A; deplacement vers DEST etc)
    #  - creation structure repertoire AAAA/MM/JJ
    #  - traitement fichier autres que photos : .THM, .MPG, picasa.ini, .db etc. 
   
    i=0
    while [ $i -lt $len ]; do

	# memorisation du rep/nom du fichier en traitement
	fichierEnTraitement="./${DIR}/${arrRepertoire[$i]}";

        # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink, puis si oui, on commence le traitement
        if [[ -f  "${fichierEnTraitement}"  &&  "${fichierEnTraitement}" != "./${DIR}/Thumbs.db" &&  "${fichierEnTraitement}" != "./${DIR}/thumbs.db" ]]
        then

	    # debut d'une section de chronometrage
	    STARTFICHIER=$(date +%s.%N)

	    # debut d'une section de chronometrage
	    START=$(date +%s.%N)



       	    # ce tableau (arrTS) contient tout les timestamps dispo [ soit CreateDate, DateTimeOriginal, FileModifyDate et stat etc.]
	    # vu que les timestamps sont inserer dans le tableau dans l'ordre adcendant, l'element [0] contient le timestamp le plus ancien et qui
	    # correspond probablement a la date de prise de la photo [CreateDate]. Exception possible : erreur quelconque qui fait que [0] 
	    # pourrait contenir 1janvier1970. Les autres elements [1],[2] etc. contiennent 
	    # des timestamps plus recents [DateTimeOriginal] [FileModifyDate] et [stat %Y]
       	    # donc on commence avec ${arrTS[0]} si il existe et ensuite on descend vers ${arrTS[1]} ${arrTS[2]} etc

	    # pour commencer on affecte a notre tableau arrTS les timestamps EXIF trouve avec soit jhead soit exiftool
	    if [ "${2}" == "1" ] # si le 2e param est 1, on utilise exiftool, sinon jhead
	    then
		arrTS=(`exiftool -e --fast -CreateDate -DateTimeOriginal -FileModifyDate  -S -d "%s" ${fichierEnTraitement}  | \
                    sed -r "s/.*: ([0-9:]*).*/\1/"`);
		echo "INFO  : traitement exiftooljhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
	    else	
		jheadTS=(`jhead -q  ${fichierEnTraitement} 2>/dev/null| grep "Date/Time" | sed -r "s/.*: ([0-9:]*).*/\1/" | tr -d ':' `)
		arrTS=(`date -d ${jheadTS} +%s 2>/dev/null`);
		echo "INFO  : traitement jhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
	    fi

            # debut d'une section de chronometrage
	    START=$(date +%s.%N)
	    

	    # ensuite si necess (c.a.d. le tableau arrTS n'as pas ete remplie par exiftool/jhead et est donc vide) et 
	    # en dernier recours, on affecte le timestamp du fichier lui-meme
	    if [ "${#arrTS[*]}" == "0" ]
	    then
		# on utilise 'stat' pour extraire le %Y = 'Time of last modification as seconds since Epoch'
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
		echo "ERREUR : pas de timestamp pour fichier : ${fichierEnTraitement} ... fin du programme.";
		exit;
	    fi 
	    

	    # info pour debug : ls et md5sum du fichier pre deplacement
	    md5FichierenTraitement=`md5sum ${fichierEnTraitement} | cut -c1-32`
	    echo "INFO  : on copie/deplace ceci : [$md5FichierenTraitement] " `ls -al ${fichierEnTraitement}`
	    
	    # et on s'apprete a copier par dessus :
	    md5FichierExistant=`md5sum ./${DEST}/${arrRepertoire[$i]} | cut -c1-32`
	    echo "INFO  : sur ceci : [$md5FichierExistant] " `ls -al ./${DEST}/${arrRepertoire[$i]}`

            # debut d'une section de chronometrage
	    START=$(date +%s.%N)




	    

	    # on deplace/copie le fichier ICI (si $3 vaut 1, on fait MV, sinon CP /; par defaut c'est donc CP)
	    # exif-photo-classifier.sh src 0 1
	    if [ "${3}" == "1" ]
	    then
		mv ${fichierEnTraitement} ${DEST}
		echo "INFO  : deplacement de : ${fichierEnTraitement} vers : ${DEST} : $(echo "$(date +%s.%N) - $START" | bc) secondes";
	    else	
		cp  --backup=numbered --preserve=all ${fichierEnTraitement} ${DEST}
		echo "INFO  : copie de : ${fichierEnTraitement} vers : ${DEST} : $(echo "$(date +%s.%N) - $START" | bc) secondes";
	    fi
	    



	    # compteur de fichier traites
	    let nbrFichierTraites++

	    # info pour debug : ls du fichier post deplacement
	    echo -n "INFO  :       dans ${DEST} : [$md5FichierExistant] " `ls -al ./${DEST}/${arrRepertoire[$i]}`
	    echo "";
	    echo "INFO  : traitement de ${fichierEnTraitement} : $(echo "$(date +%s.%N) - $STARTFICHIER" | bc) secondes";echo "";echo "";
            

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
