#!/bin/bash
# $Id$

# pour chaque fichier, le comparer aux signatures de
# fichiers déjà présent dans le répertoire de destination, puis :
# ATTENTION : quoi faire avec les fichiers connexes ? [Picasa.ini, *.MPG, *.THM etc...]


#TMPFILE=$(tempfile)
#trap 'echo "removing $TMPFILE ; BASHTRAP=1"; rm -f $TMPFILE' INT TERM EXIT


# tee : scrit
# ex : exif-photo-classifier.sh ~/Pictures/ 2>logfile.txt | tee logfile.txt


# tests :
# 0. fichiers de diff types correctement deplace/copie
# 1. touch du fichier de l'ancien rep correctement cree
# 2. concatenation des donnees picasa le cas echeant



STARTGLOBAL=$(date +%s.%N)

CP=/bin/cp
RM=/bin/rm
MKDIR=/bin/mkdir
TOUCH=/usr/bin/touch
JHEAD=/usr/bin/jhead
SSDEEP=/usr/local/bin/ssdeep
MD5SUM=/usr/bin/md5sum

nbrFichierTraites=0;
nbrFichierCopie=0;
nbrFichierRenomme=0;
nbrFichierEfface=0;
nbrErreur=0;


SRC=$1
DEST=""

OUTILS=${2:-"0"}
DEPLACE=${3:-"0"}



DRY_RUN=""
if [ ${DRY_RUN} ];
then
  DRY_RUN=" DRY RUN "
  CP="/bin/echo INFO $DRY_RUN : $CP"
  RM="/bin/echo INFO $DRY_RUN : $RM"
  MKDIR="/bin/echo INFO $DRY_RUN : $MKDIR"
  TOUCH="/bin/echo INFO $DRY_RUN : $TOUCH"
fi


SSDEEP=/usr/local/bin/ssdeep
[ ! -x "${SSDEEP}" ] && logerreur "ERREUR : ${SSDEEP} n'esxiste pas" && exit;

detox -r -v -s utf_8 "${SRC}"
# hummm...ca brise la rechereche de nom dans les Picasa.ini ...
# detox -r -v -s lower "${SRC}"





########################################################################
########################################################################
# fonctions ci-dessous
########################################################################
########################################################################



########################################################################
# effacer : efface le ficheir passer en param $1
########################################################################
function effacer {

  fichier_1=${1}
  echo "INFO $DRY_RUN  : effacer()  : debut traitement de $fichier_1";


  $RM -f $fichier_1

  if [ $? -ne 0 ]; then
    echo
    echo "Directory does not exists"
    echo "Please try again."
    echo
    exit 0
  fi

  let nbrFichierEfface++
  return 1
}

########################################################################
# copier : copie le fichier $1 (param 1) vers le fichier $2 (param 2)
########################################################################
function copier {

  fichier_1=${1}
  fichier_2=${2}

  echo "INFO $DRY_RUN  : copier()  : debut traitement de ${fichier_1} et ${fichier_2}";

  $CP -fp $fichier_1 $fichier_2

  if [ $? -ne 0 ]; then
    logerreur "ERREUR : copier() : $fichier_1 et $fichier_2";
    exit 0
  fi


  let nbrFichierCopie++
  return 1
}

########################################################################
# copier : memorise le rep d'origine d'un ficheir
#   en faisant un 'touch' sur un fichier vide avec le nom du rep
########################################################################
function memorise_ancien_rep {
  fichier_1=${1}
  fichier_2=${2}

  # extraction l'ancien rep ou se trouvait l'image
  ancien_repertoire=(`echo ${fichier_1} | tr '/' '_'`)
  # extraction du nouveau rep de destination
  nouveau_repertoire=${fichier_2}

  # ds le rep de dest, on cree un fichier vide afin de memoriser les
  # differents rep d'origine des photos
  $TOUCH $nouveau_repertoire/"ANCIEN_REP_SRC-"$ancien_repertoire
}

########################################################################
# traitement_picasa : on fait le traitement picasa,
#   c.a.d.: on fait suivre les donnees picasa.ini
#   du fichier en cours de traitement vers son nouveau rep
#   -> on copie ds dest/picasa.ini la section [fichier.jpg] si presente
########################################################################
function traitement_picasa {

  fichier_1=${1}
  fichier_2=${2}

	# copy Picasa.ini entries
	srcDir=`dirname "$fichier_1"`

	if [ -e "$srcDir/Picasa.ini" ]; then

		srcFileName=`basename "$fichier_1"`
		destDir=`dirname "$fichier_2"`
		destFileName=`basename "$fichier_2"`

		# setup new Picasa.ini
		if [ ! -e "$destDir/Picasa.ini" ]; then
			echo -e -n '[encoding]\x0D\x0Autf8=1\x0D\x0A' \
				> "$destDir/Picasa.ini"
		fi

		# read picasa.ini add [ to start for gawk
		echo "\[" | cat - "$srcDir/Picasa.ini" | \

		# separate on [ and print first entry with $srcFileName
		gawk 'BEGIN {RS="[";m=0} /'"$srcFileName"'/ {m++; if(m==1) print}' | \

		# replace old name with the new file name
		sed "s/$srcFileName\]/\[$destFileName\]/" | \

		# remove blank lines and convert to CRLF  [ ci-dessous : trouve pas u2d ds grep '.' | u2d -D >> ]
		grep '.' |  sed 's/$'"/`echo \\\r`/" "$destDir/Picasa.ini"
	fi

  return 1;
}

########################################################################
# renommer : renomme le fichier $1 (param 1) vers le fichier $2 (param 2)
########################################################################
function renommer {

  fichier_src=(`basename ${1}`)
  rep_src=(`dirname ${1}`)
  fichier_dest=(`basename ${2}`)
  rep_dest=(`dirname ${2}`)

  echo "INFO $DRY_RUN  : renommer()  : debut traitement de $fichier_src";

  copier $rep_src/$fichier_src $rep_dest/"BACKUP."`date +"%dj%mm%Ya_%Hh%Mm%Ss"  | tr \'[:upper:]\' \'[:lower:]\'`.$fichier_dest

  # on veut pas compter 2 fois cette copie
  let nbrFichierCopie--

  let nbrFichierRenomme++

  return $?
}

########################################################################
# signatures_md5_sont_identiques : compare les sig md5 de fichier $1 (param 1)
#   et fichier $2 (param 2); retourne 1 si identiques, 0 sinon
########################################################################
function signatures_md5_sont_identiques {

  fichier_1=${1}
  fichier_2=${2}

  md5fichier_1=(`md5sum ${fichier_1}  2>/dev/null | cut -c1-32 `)
  md5fichier_2=(`md5sum ${fichier_2}  2>/dev/null | cut -c1-32 `)

  # echo "INFO $DRY_RUN  : signatures_md5_sont_identiques()  : debut traitement de $fichier_1 et $fichier_2";

  if [ "${md5fichier_1}" == "${md5fichier_2}" ]
  then
    # fichiers identiques
    echo "INFO $DRY_RUN  : signatures_md5_sont_identiques()  : $fichier_1 [${md5fichier_1}] === \
      $fichier_2 [${md5fichier_2}]";
    return 1;
  else
    # fichiers sont differents
    echo "INFO $DRY_RUN  : signatures_md5_sont_identiques()  : $fichier_1 [${md5fichier_1}] !== $fichier_2 [${md5fichier_2}]";
    return 0;
  fi
}

########################################################################
# signatures_SSD_sont_identiquesr : compare les sig ssdeep de fichier $1
#   (param 1) et fichier $2 (param 2); retroune 1 si leur % de
#   similitude estsuperieur ou egale a 'limite', 0 sinon
########################################################################
function signatures_SSD_sont_identiques {

  # au sujet de la vaiable 'limite' ci-dessous
  # ssdeep retourne un poucentage d'affiliation entre 2 fichiers...avec 2 fichiers
  # completement differents, ssdeep retroune 0%, avec 2 fichiers identiques,
  # il retourne 100%...donc cete fonction (signatures_SSD_sont_identiques)
  # declare 2 fichiers identiques si leur degre d'affiliation est superieur
  # ou egale a 'limite'. Donc avec limite = 100, on ne trouveras jamais 2 fichiers
  # egaux. C'est l'option la plus conservatrice, car on s'assure de pas perdre
  # d'informations (ex: on ne perdras pas un comentaire exif modifie)
  fichier_1=${1}
  fichier_2=${2}

  ssdeepres=-1
  limite=100

  echo "INFO $DRY_RUN  : signatures_SSD_sont_identiques()  : debut traitement de $fichier_1 et $fichier_2";

  ssdeep -s -b ${fichier_1} > /tmp/sig.txt

  ssdeepres=(`ssdeep -bam /tmp/sig.txt ${fichier_2}  2>/dev/null | sed -r "s/.*\(([0-9]*)\)/\\1/"`)

  if [ $ssdeepres -ge $limite ]
  then
    # fichiers ont un % de similitude superieur ou egale a 'limite'
    echo "INFO $DRY_RUN  : signatures_SSD_sont_identiques()  : 1 ssdeep retourne $ssdeepres \
      pour ${md5fichier_1} et ${md5fichier_2} et limite = $limite";
    return 1
  else
    # fichiers sont suffisament different pour avoir un % de similitude inferieur a 'limite'
    echo "INFO $DRY_RUN  : signatures_SSD_sont_identiques()  : 0 ssdeep retourne $ssdeepres \
      pour ${md5fichier_1} et ${md5fichier_2} et limite = $limite";
    return 0
  fi

}

########################################################################
# noms_de_fichier_sont_identiques : compare les noms de fichier $1
#   (param 1) et fichier $2 (param 2); retourne 1 si identiques, 0 sinon
########################################################################
function noms_de_fichier_sont_identiques {

  fichier_1=(`basename ${1}`)
  fichier_2=(`basename ${2}`)


  echo "INFO $DRY_RUN  : noms_de_fichier_sont_identiques() : debut traitement de $fichier_1 et $fichier_2";

  if [ "${fichier_1}" == "${fichier_2}" ]
  then
    # meme noms
    return 1;
  else
    # nom differents
    return 0
  fi
}




########################################################################
# logerreur : affiche les erreurs et incremente un compteur
########################################################################
function logerreur {
  echo $1;
  let nbrErreur++
}



########################################################################
########################################################################
########################################################################
# code principal
########################################################################
########################################################################
########################################################################


for DIR in `find "${SRC}" -depth -type d -print 2> /dev/null`;
# -depth = :
#./2007/12/15
#./2007/12
#./2007
do


#   if [ $BASHTRAP -eq 1 ]
#   then
#     break;
#   fi

  # traitement sur les fichiers trouve ds le repertoire $DIR
  # traitement picasa.ini

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
      fichierEnTraitement="${DIR}/${arrRepertoire[$i]}";

      # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink,
      # puis si oui, on commence le traitement
      if [[ -f  "${fichierEnTraitement}"  &&
            "${arrRepertoire[$i]}" != "Thumbs.db" &&
            "${arrRepertoire[$i]}" != "thumbs.db" &&
            "${arrRepertoire[$i]}" != "Picasa.ini" &&
            "${arrRepertoire[$i]}" != "picasa.ini" ]]
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
        if [ "${OUTILS}" == "1" ] # si le param OUTILS est 1, on utilise exiftool, sinon jhead
        then
          arrTS=""
          arrTS=(`exiftool -e --fast -CreateDate -DateTimeOriginal -FileModifyDate \
            -S -d "%s" ${fichierEnTraitement}  | \
            sed -r "s/.*: ([0-9:]*).*/\1/"`);
          echo "INFO $DRY_RUN  : traitement exiftool : $(echo "$(date +%s.%N) - $START" | bc) secondes";
        else
          jheadTS=""
          jheadTS=(`jhead -q  ${fichierEnTraitement} 2>/dev/null| grep "Date/Time" | \
            sed -r "s/.*: ([0-9:]*).*/\1/" | tr -d ':' `)
          arrTS=(`date -d ${jheadTS} +%s 2>/dev/null`);
          echo "INFO $DRY_RUN  : traitement jhead : $(echo "$(date +%s.%N) - $START" | bc) secondes";
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
          echo "INFO $DRY_RUN  : pas de date EXIF, on utilise 'stat'...";
          StatTS=(`stat --format='%Y'  ${fichierEnTraitement}  `);
          # on ajoute ce timestamp a notre tableau
          arrTS[${#arrTS[*]}]=$StatTS;
              echo "INFO $DRY_RUN  : traitement stat : $(echo "$(date +%s.%N) - $START" | bc) secondes";
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
            $MKDIR -p ${DEST} ;
            echo "INFO $DRY_RUN  : traitement mkdir ${DEST} : $(echo "$(date +%s.%N) - $START" | bc) secondes";
          fi
        else
          logerreur "ERREUR  : pas de timestamp pour : ${fichierEnTraitement} ... fin du programme.";
          exit;
        fi





        # info pour debug : ls et md5sum du fichier pre deplacement
        md5FichierenTraitement=`md5sum ${fichierEnTraitement}  2>/dev/null | cut -c1-32 `
        echo "INFO $DRY_RUN  : on s\'apprete a copie/deplace ceci : [$md5FichierenTraitement] " \
          `ls -al ${fichierEnTraitement} 2>/dev/null`

        if [ ! -e "./${DEST}/${arrRepertoire[$i]}" ]; then


          # copier le nouveau fichier ds DEST
          copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
          memorise_ancien_rep ${DIR} ./${DEST}/  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
          traitement_picasa ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}

          if [ "${DEPLACE}" == "1" ]
          then
            effacer  ${fichierEnTraitement}
          fi

        else

          # cas ou le fichier existe deja ds la DEST
          # et on s'apprete a copier par dessus :
          md5FichierExistant=`md5sum ./${DEST}/${arrRepertoire[$i]}  2>/dev/null | cut -c1-32 `
          echo "INFO $DRY_RUN  : sur ceci : [$md5FichierExistant] " `ls -al ./${DEST}/${arrRepertoire[$i]} \
            2>/dev/null`

          signatures_md5_sont_identiques ${fichierEnTraitement} ./${DEST}/${arrRepertoire[$i]}
          md5retcode=$?

          if [ "$md5retcode" == "1" ]
          then

            # effacer ou ignorer fichier source, car md5 identique = fichiers identiques
            if [ "${DEPLACE}" == "1" ]
            then
              effacer  ${fichierEnTraitement}
            fi

          elif [ "$md5retcode" == "0" ]
          then

            # sig md5 sont differentes, on va test plus loin avec ssdeep
            signatures_SSD_sont_identiques  ${fichierEnTraitement} \
              ./${DEST}/${arrRepertoire[$i]}
            ssdretcode=$?

            if [ "$ssdretcode" == "1" ]
            then
              echo " # effacer ou ignorer fichier source, car ssdeep identique = fichiers identiques"
              if [ "${DEPLACE}" == "1" ]
              then
                effacer  ${fichierEnTraitement}
              fi

            elif [ "$ssdretcode" == "0" ]
            then
              # sig ssdeep sont differentes, on va plus loin avec les noms de fichiers"
              noms_de_fichier_sont_identiques  ${fichierEnTraitement} \
                ./${DEST}/${arrRepertoire[$i]}
              nomretcode=$?
#### attention : faire test a savoir si A a une taille plus petite que A`
              if [ "$nomretcode" == "1" ]
              then

                # faire backup du fichier existant
                renommer  ${fichierEnTraitement} ./${DEST}/${arrRepertoire[$i]}

                # copier le nouveau fichier ds DEST
                copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
                memorise_ancien_rep ${DIR} ./${DEST}/  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
                traitement_picasa  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}

                if [ "${DEPLACE}" == "1" ]
                then
                  effacer  ${fichierEnTraitement}
                fi
              elif [ "$nomretcode" == "0" ]
              then

                # noms de ficheirs sont differents
                copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
                memorise_ancien_rep ${DIR} ./${DEST}/  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
                traitement_picasa   ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}

                if [ "${DEPLACE}" == "1" ]
                then
                  effacer  ${fichierEnTraitement}
                fi
              else

                # sig ssdeep sont egales
                logerreur "ERREUR : ds noms_de_fichier_sont_identiques [$?]"
              fi
            else

              # sig ssdeep sont egales
              logerreur "ERREUR : ds signatures_SSD_sont_identiques [$?]"
            fi
          else
            # erreur
            logerreur "ERREUR : ds signatures_md5_sont_identiques [$?]"
          fi

        fi

        # compteur de fichier traites
        let nbrFichierTraites++

        # info pour debug : ls du fichier post deplacement
        echo "INFO $DRY_RUN  : traitement de ${fichierEnTraitement} : $(echo "$(date +%s.%N) - $STARTFICHIER"\
                       | bc) secondes";echo "";echo "";


      else
        # on determine qu'il s'agit bien d'un repertoire ou symlink et non pas d'un fichier
        # DONC :rien a faire, on passe au suivant
        echo "INFO $DRY_RUN  : il [$fichierEnTraitement] s'agit d'un repertoire, "\
          "symlink ou fichier indesirable, on passe au prochain element...";
        echo ""
        echo ""
      fi



      let i++
    done
done



# output d'info/debug
echo "INFO $DRY_RUN  : ${nbrFichierTraites} fichiers/repertoires ont ete examines/traites.";
echo "INFO $DRY_RUN  : ${nbrFichierCopie} fichiers ont ete copie.";
echo "INFO $DRY_RUN  : ${nbrFichierEfface} fichiers se trouvant deja dans la destination ont ete efface de la source [${SRC}].";
echo "INFO $DRY_RUN  : ${nbrFichierRenomme} fichiers ont ete renommer";
echo "INFO $DRY_RUN  : ${nbrErreur} ERREURS ont ete trouver";
echo "INFO $DRY_RUN  : traitement TOTAL : $(echo "$(date +%s.%N) - $STARTGLOBAL" | bc) secondes";



exit;




#if signatures_md5_sont_identiques() {
#       effacer()
#     }
#     else{
#       if signatures_SSD_sont_identiques() {
#            effacer()
#         }
#         else{
#            if noms_de_fichier_sont_identiques() {
#                 renommer()
#                 copier()
#                 effacer()
#               }
#               else{
#                 copier()
#                 effacer()
#               }
#         }
#     }
