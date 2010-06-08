#!/bin/bash
# pour chaque fichier, le comparer aux signatures de 
# fichiers déjà présent dans le répertoire de destination, puis :
# ATTENTION : quoi faire avec les fichiers connexes ? [Picasa.ini, *.MPG, *.THM etc...]
SRC=$1
detox -v -s utf_8 "${SRC}"
detox -v -s lower "${SRC}"
 
for DIR in `find "${SRC}" -type d -depth -print 2> /dev/null`;
# -depth = :
#./2007/12/15
#./2007/12
#./2007
do
    # traitement sur les fichiers trouvé ds le répertoire $DIR
 
    # on met les fichiers du rep DIR dans un tableau
    array=( ` ls  "${DIR}" ` ) ;
 
    # on extrait le mombre d'element du tableau
    len=${#array[*]}
 
    echo "The array for '"${DIR}"' has $len members. They are:"
 
    # on boucle sur les elements du tableau
    i=0
    while [ $i -lt $len ]; do
        # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink
        if [ -f  "${DIR}/${array[$i]}" ]
        then
                #  - traitement sur chacun des fichiers (md5, ssdeep; extraction exiftool de J,M,A; deplacement vers DEST etc)
                #  - creation structure repertoire AAAA/MM/JJ
                #  - traitement fichier autres que photos : .THM, .MPG, picasa.ini, .db etc. 
       		echo -n "$i: ${array[$i]}"
 
       		# extraction des timestamps
       		a=(`exiftool -CreateDate -DateTimeOriginal -FileModifyDate  -S -d "%s" ${array[$i]} | \
                                     sed -r "s/.*: ([0-9:]*).*/\1/"`  `stat --format='%Y'  ${array[$i]}  `);
 
       		# ce tableau contient tout les timestamps dispo [ soit CreateDate, DateTimeOriginal, FileModifyDate  et stat ]
       		echo ${a[@]}
       		echo ${a[1]}
 
       		# ensuite on transforme ces timestmaps en AAAA,MM,JJ
       		# donc on commence avec ${a[0]} si il existe et ensuite on descend vers ${a[1]} ${a[2]} etc
       		b=( `date +'%Y %m %d' -d @${a[0]}` )
 
                # on cree le repertoire DEST
                # ce repertoire sera utilise pour deplacer les fichier qui ne sont pas des images (exiftool retrourneras '1')
                # le repertoire que l'on voudras cree : 
                ${b[0]}/${b[1]}/${b[2]}
 
 
               # ici , on pourrait tester avec MD5 ou ssdeep
 
                # on utilise exiftool pour deplacer les photos, c'est plus pratique avec la numerotion auto en cas de doublon
                # exiftool ne retourne 0 que si il a reussi a extraire des donnees EXIF...donc si il ret 1, c que ce n'est pas une photo
                # contenant des donnees EXIF OU ALORS que c'est Picasa.ini ou un MPG, THM, thumbs.db etc.
                exiftool  -P -r -d %Y/%m/%d/%f%+c.%%e "-filename<datetimeoriginal" -o dest/ ${array[$i]}
	       #on test sur $? : si '0', le fichier etait une image et est rendu ds DEST
                                     #si '1' : c\'est soit un film, picasa.ini ou autre : on copy dans 	${b[0]}/${b[1]}/${b[2]}  
                RETCODE=$?
                #if error ...:
                if [ $RETCODE -ne 0 ];
                then
                       # si '0', le fichier etait une image et est rendu ds DEST
                else
                       #si '1' : c\'est soit un film, picasa.ini ou autre : on copy dans 	${b[0]}/${b[1]}/${b[2]}  
                fi
 
               echo "============================="
        fi
 
	let i++
    done
done
 
