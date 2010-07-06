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
# ok # 0. fichiers de differents types correctement deplace/copie
# ok # 1. touch du fichier de l'ancien rep correctement cree
# ok : on fait detox -slower et picasa() fait aussi tolower  ## 3. upper / lower ?
# ok # 2. concatenation des donnees picasa le cas echeant
# ok # parametrer les executables
# pas necess vu que l'on test avec md5 # 5. faire test a savoir si A a une taille plus petite que A`

STARTGLOBAL=$(date +%s.%N)

CP=/bin/cp
RM=/bin/rm
MKDIR=/bin/mkdir
TOUCH=/usr/bin/touch
JHEAD=/usr/bin/jhead
SSDEEP=/usr/local/bin/ssdeep
MD5SUM=/usr/bin/md5sum
DETOX=/usr/bin/detox
ECHO=/bin/echo
CAT=/bin/cat
GREP=/bin/grep
SED=/bin/sed
AWK=/usr/bin/gawk
TR=/usr/bin/tr

nbrFichierTraites=0;
nbrFichierCopie=0;
nbrFichierRenomme=0;
nbrFichierEfface=0;
nbrInfo=0;
nbrAlerte=0;
nbrErreur=0;
nbrRepertoire=0;
nbrTotalFichierRepExamine=0;

SRC=$1
DEST=""

OUTILS=${2:-"0"}
DEPLACE=${3:-"0"}



DRY_RUN="" # "1" = dry-run, donc on ne touche pas aux fichiers,
           # "" = on fait le travail pour vrai
if [ "${DRY_RUN}" == "1" ];
then
  DRY_RUN=" DRY RUN "
  CP="$ECHO INFO $DRY_RUN : $CP"
  RM="$ECHO INFO $DRY_RUN : $RM"
  MKDIR="$ECHO INFO $DRY_RUN : $MKDIR"
  TOUCH="$ECHO INFO $DRY_RUN : $TOUCH"
  DETOX="$ECHO INFO $DRY_RUN : $DETOX"
fi


SSDEEP=/usr/local/bin/ssdeep
[ ! -x "${SSDEEP}" ] && logmessage "ERREUR" "${SSDEEP} n'esxiste pas" && exit;

$DETOX -r -v -s utf_8 "${SRC}"
# ATTRENTION : si on cesse d'utiliser detox -s lower, il faut aussi changer
# le code de la fonction picasa(), car elle transforme en lower, les
# noms de [fichiers.jpg] ds les picasa.ini
$DETOX -r -v -s lower "${SRC}"




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
  logmessage "INFO" "debut traitement de ${fichier_1}" "DEBUG_0"


  $RM -f $fichier_1

  if [ $? -ne 0 ]; then
    logmessage "ERREUR" "commande [$RM] a echouee pour [${fichier_1}]"
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

  logmessage "INFO" "debut traitement de ${fichier_1} et ${fichier_2}" "DEBUG_0"

  $CP -fp $fichier_1 $fichier_2

  if [ $? -ne 0 ]; then
    logmessage "ERREUR" "commande [$CP] a echouee pour [${fichier_1} et ${fichier_2}]"
    exit 0
  fi


  let nbrFichierCopie++
  return 1
}

########################################################################
# copier : memorise le rep d'origine d'un ficheir
#   en faisant un 'touch' sur un fichier vide avec le nom du rep
########################################################################
function ancien_rep {
  srcDir=${1}
  fichier_2=${2}

  destDir=`dirname "$fichier_2"`

  # extraction l'ancien rep ou se trouvait l'image
  ancien_repertoire=(`$ECHO ${srcDir} | $TR '/' '.' `)
  # extraction du nouveau rep de destination
  nouveau_repertoire=${destDir}

  # ds le rep de dest, on cree un fichier vide afin de memoriser les
  # differents rep d'origine des photos
  logmessage "INFO" "$TOUCH -r $fichier_2 $nouveau_repertoire/ANCIEN_REP_SRC-$ancien_repertoire" "DEBUG_0"
  $TOUCH -r $fichier_2 $nouveau_repertoire/"ANCIEN_REP_SRC-"$ancien_repertoire
}

########################################################################
# picasa : on fait le traitement picasa,
#   c.a.d.: on fait suivre les donnees picasa.ini
#   du fichier en cours de traitement vers son nouveau rep
#   -> on copie ds dest/picasa.ini la section [fichier.jpg] si presente
########################################################################
function picasa {

  fichier_1=${1}
  fichier_2=${2}

  srcFileName=`basename "$fichier_1"`
  srcDir=`dirname "$fichier_1"`
  destDir=`dirname "$fichier_2"`
  destFileName=`basename "$fichier_2"`


  logmessage "INFO" "debut traitement de $fichier_1" "DEBUG_0";


  # determiner le nom di ficheir picasa existant
  if   [[ -e "$srcDir/Picasa.ini" ]]
  then
    srcPicasa="Picasa.ini"
  elif [[ -e "$srcDir/picasa.ini" ]]
  then
    srcPicasa="picasa.ini"
  elif [[ -e "$srcDir/.Picasa.ini" ]]
  then
    srcPicasa=".Picasa.ini"
  elif [[ -e "$srcDir/.picasa.ini" ]]
  then
    srcPicasa=".picasa.ini"
  else
    logmessage "INFO" "fichier $srcDir/[.pP]icasa.ini n'existe pas" "DEBUG_0";
    return 1
  fi



  # setup new Picasa.ini
  if [ ! -e "$destDir/picasa.ini" ];
  then
    logmessage "INFO" "creation d'un fichier vierge : $destDir/picasa.ini" "DEBUG_0";

    $ECHO -e -n '[encoding]\x0D\x0Autf8=1\x0D\x0A' \
      > "$destDir/picasa.ini"
  fi


  # read picasa.ini add [ to start for awk
  $ECHO "" | $CAT - "$srcDir/$srcPicasa" | \

  # separate on [ and print first entry with $srcFileName
  $AWK 'BEGIN {RS="[";m=0; IGNORECASE=1} /'"$srcFileName"'/ {m++; if(m==1) print "["$0 }' | \

  # replace old name with the new file name + to lower
  $SED "s/$srcFileName\]/\[$destFileName\]/" |  $TR '[:upper:]' '[:lower:]' | \

  # remove blank lines and convert to CRLF  [ ci-dessous : trouve pas u2d ds grep '.' | u2d -D >> ]
  $GREP '.' |  $SED 's/$'"/`$ECHO \\\r`/" >> "$destDir/picasa.ini"

  logmessage "INFO" "donnees ont ete copier de $srcDir/$srcPicasa vers $destDir/picasa.ini" "DEBUG_0";

  return 0;
}

########################################################################
# renommer : renomme le fichier $1 (param 1) vers le fichier $2 (param 2)
########################################################################
function renommer {

  fichier_src=(`basename ${1}`)
  rep_src=(`dirname ${1}`)
  fichier_dest=(`basename ${2}`)
  rep_dest=(`dirname ${2}`)

  logmessage "INFO" "debut traitement de $fichier_src" "DEBUG_0";

  # upper/lower utiliser uniquement pour que la date soit en minuscules
  copier $rep_src/$fichier_src $rep_dest/"BACKUP."`date +"%dj%mm%Ya_%Hh%Mm%Ss"  | $TR \'[:upper:]\' \'[:lower:]\'`.$fichier_dest

  # on veut pas compter 2 fois cette copie
  let nbrFichierCopie--

  let nbrFichierRenomme++

  return $?
}

########################################################################
# verif_md5 : compare les sig md5 de fichier $1 (param 1)
#   et fichier $2 (param 2); retourne 1 si identiques, 0 sinon
########################################################################
function verif_md5 {

  fichier_1=${1}
  fichier_2=${2}

  md5fichier_1=(`md5sum ${fichier_1}  2>/dev/null | cut -c1-32 `)
  md5fichier_2=(`md5sum ${fichier_2}  2>/dev/null | cut -c1-32 `)

  logmessage "INFO" "debut traitement de $fichier_1 et $fichier_2";

  if [ "${md5fichier_1}" == "${md5fichier_2}" ]
  then
    # fichiers identiques
    logmessage "INFO" "$fichier_1 [${md5fichier_1}] === \
      $fichier_2 [${md5fichier_2}]" "DEBUG_0";
    return 1;
  else
    # fichiers sont differents
    logmessage "INFO" "$fichier_1 [${md5fichier_1}] !== $fichier_2 [${md5fichier_2}]" "DEBUG_0";
    return 0;
  fi
}

########################################################################
# verif_ssdr : compare les sig ssdeep de fichier $1
#   (param 1) et fichier $2 (param 2); retroune 1 si leur % de
#   similitude estsuperieur ou egale a 'limite', 0 sinon
########################################################################
function verif_ssd {

  # au sujet de la vaiable 'limite' ci-dessous
  # ssdeep retourne un poucentage d'affiliation entre 2 fichiers...avec 2 fichiers
  # completement differents, ssdeep retroune 0%, avec 2 fichiers identiques,
  # il retourne 100%...donc cete fonction (verif_ssd)
  # declare 2 fichiers identiques si leur degre d'affiliation est superieur
  # ou egale a 'limite'. Donc avec limite = 100, on ne trouveras jamais 2 fichiers
  # egaux. C'est l'option la plus conservatrice, car on s'assure de pas perdre
  # d'informations (ex: on ne perdras pas un comentaire exif modifie)
  fichier_1=${1}
  fichier_2=${2}

  ssdeepres=-1
  limite=100

  logmessage "INFO" "debut traitement de $fichier_1 et $fichier_2" "DEBUG_0";

  ssdeep -s -b ${fichier_1} > /tmp/sig.txt

  ssdeepres=(`ssdeep -bam /tmp/sig.txt ${fichier_2}  2>/dev/null | $SED -r "s/.*\(([0-9]*)\)/\\1/"`)

  if [ $ssdeepres -ge $limite ]
  then
    # fichiers ont un % de similitude superieur ou egale a 'limite'
    logmessage "INFO" "1 ssdeep retourne $ssdeepres \
      pour ${md5fichier_1} et ${md5fichier_2} et limite = $limite";
    return 1
  else
    # fichiers sont suffisament different pour avoir un % de similitude inferieur a 'limite'
    logmessage "INFO" "0 ssdeep retourne $ssdeepres \
      pour ${md5fichier_1} et ${md5fichier_2} et limite = $limite";
    return 0
  fi

}

########################################################################
# verif_nom : compare les noms de fichier $1
#   (param 1) et fichier $2 (param 2); retourne 1 si identiques, 0 sinon
########################################################################
function verif_nom {

  fichier_1=(`basename ${1}`)
  fichier_2=(`basename ${2}`)


  logmessage "INFO" "debut traitement de $fichier_1 et $fichier_2" "DEBUG_0";

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
# logmessage : affiche les message et incremente un compteur par type
# de message
########################################################################
function logmessage {

  type=${1}; # ERREUR,INFO, ALERTE
  message=${2};
  debug=${3};

  if [ "${debug}" != "DEBUG_" ]
  then

    case $type in
      "INFO" )
        let nbrInfo++ ;;
      "ERREUR" )
        let nbrErreur++ ;;
      "ALERTE" )
        let nbrAlerte++ ;;
      *   )
        printf "ERREUR\t: [$type] n'est pas defini; message ci-dessous "\
               "[$message] ne sera pas imprimes correctement.\n" ;;
    esac


    printf "$type $DRY_RUN\t: [${FUNCNAME[1]}]\t: $message\n"
  fi
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


  # compteur de repertoire
  let nbrRepertoire++


  # on met les fichiers du rep DIR dans un tableau
  arrRepertoire=( ` ls  "${DIR}" ` ) ;
  logmessage "INFO" "-- $nbrRepertoire ----------------------------------------------------------------------------------------------------------"
  logmessage "INFO" "debut traitement rep [${DIR}]"

  # on extrait le mombre d'element du tableau
  len=${#arrRepertoire[*]}

  # on boucle sur les elements du tableau
  #  - traitement sur chacun des fichiers (md5, ssdeep; extraction exiftool de J,M,A;
  #    deplacement vers DEST etc)
  #  - creation structure repertoire AAAA/MM/JJ
  #  - traitement fichier autres que photos : .THM, .MPG, picasa.ini, .db etc.

  i=0
  while [ $i -lt $len ]; do

    # compteur rep ET fichier examines
    let nbrTotalFichierRepExamine++


    # memorisation du rep/nom du fichier en traitement
    fichierEnTraitement="${DIR}/${arrRepertoire[$i]}";

    # on determine qu'il s'agit bien de fichier et non pas de repertoire ou symlink,
    # puis si oui, on commence le traitement
    if [[ -f  "${fichierEnTraitement}"  &&
          "${arrRepertoire[$i]}" != "Thumbs.db" &&
          "${arrRepertoire[$i]}" != "thumbs.db" &&
          "${arrRepertoire[$i]}" != "Picasa.ini" &&
          "${arrRepertoire[$i]}" != "picasa.ini" &&
          "${arrRepertoire[$i]}" != ".Picasa.ini" &&
          "${arrRepertoire[$i]}" != ".picasa.ini" ]]
    then

      # compteur de fichier traites, donc on ne compte pas les rejets NI les rep
      let nbrFichierTraites++

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
          $SED -r "s/.*: ([0-9:]*).*/\1/"`);
        logmessage "INFO" "traitement exiftool : $($ECHO "$(date +%s.%N) - $START" | bc) secondes" "DEBUG_0";
      else
        jheadTS=""
        jheadTS=(`jhead -q  ${fichierEnTraitement} 2>/dev/null| $GREP "Date/Time" | \
          $SED -r "s/.*: ([0-9:]*).*/\1/" | $TR -d ':' `)
        arrTS=(`date -d ${jheadTS} +%s 2>/dev/null`);
        logmessage "INFO" "traitement jhead : $($ECHO "$(date +%s.%N) - $START" | bc) secondes" "DEBUG_0";
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
        logmessage "ALERTE" "pas de date EXIF, on utilise 'stat'...";
        StatTS=(`stat --format='%Y'  ${fichierEnTraitement}  `);
        # on ajoute ce timestamp a notre tableau
        arrTS[${#arrTS[*]}]=$StatTS;
        logmessage "INFO" "traitement stat : $($ECHO "$(date +%s.%N) - $START" | bc) secondes" "DEBUG_0";
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
          logmessage "INFO" "traitement mkdir ${DEST} : $($ECHO "$(date +%s.%N) - $START" | bc) secondes" "DEBUG_0";
        fi
      else
        logmessage "ERREUR" "pas de timestamp pour : ${fichierEnTraitement} ... fin du programme.";
        exit;
      fi





      # info pour debug : ls et md5sum du fichier pre deplacement
      md5FichierenTraitement=`md5sum ${fichierEnTraitement}  2>/dev/null | cut -c1-32 `
      logmessage "INFO" "on s\'apprete a copie/deplace ceci : [$md5FichierenTraitement] \
          `ls -al ${fichierEnTraitement} 2>/dev/null`" "DEBUG_0"

      if [ ! -e "./${DEST}/${arrRepertoire[$i]}" ]; then


        # copier le nouveau fichier ds DEST
        copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
        ancien_rep ${DIR} ./${DEST}/${arrRepertoire[$i]}  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
        picasa ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
        picasa  ${SRC}/${arrRepertoire[$i]}  ./${DEST}/${arrRepertoire[$i]}

        if [ "${DEPLACE}" == "1" ]
        then
          effacer  ${fichierEnTraitement}
        fi

      else

        # cas ou le fichier existe deja ds la DEST
        # et on s'apprete a copier par dessus :
        md5FichierExistant=`md5sum ./${DEST}/${arrRepertoire[$i]}  2>/dev/null | cut -c1-32 `
        logmessage "INFO" "sur ceci : [$md5FichierExistant] `ls -al ./${DEST}/${arrRepertoire[$i]} \
            2>/dev/null`" "DEBUG_0"

        verif_md5 ${fichierEnTraitement} ./${DEST}/${arrRepertoire[$i]}
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
          verif_ssd  ${fichierEnTraitement} \
            ./${DEST}/${arrRepertoire[$i]}
          ssdretcode=$?

          if [ "$ssdretcode" == "1" ]
          then
            # effacer ou ignorer fichier source, car ssdeep identique = fichiers identiques
            if [ "${DEPLACE}" == "1" ]
            then
              effacer  ${fichierEnTraitement}
            fi

          elif [ "$ssdretcode" == "0" ]
          then
            # sig ssdeep sont differentes, on va plus loin avec les noms de fichiers"
            verif_nom  ${fichierEnTraitement} \
              ./${DEST}/${arrRepertoire[$i]}
            nomretcode=$?

            if [ "$nomretcode" == "1" ]
            then

              # faire backup du fichier existant
              renommer  ${fichierEnTraitement} ./${DEST}/${arrRepertoire[$i]}

              # copier le nouveau fichier ds DEST
              copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              ancien_rep ${DIR} ./${DEST}/${arrRepertoire[$i]}  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              picasa  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              picasa  ${SRC}/${arrRepertoire[$i]}  ./${DEST}/${arrRepertoire[$i]}

              if [ "${DEPLACE}" == "1" ]
              then
                effacer  ${fichierEnTraitement}
              fi
            elif [ "$nomretcode" == "0" ]
            then

              # noms de ficheirs sont differents
              copier  ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              ancien_rep ${DIR} ./${DEST}/${arrRepertoire[$i]}  #${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              picasa   ${fichierEnTraitement}  ./${DEST}/${arrRepertoire[$i]}
              picasa  ${SRC}/${arrRepertoire[$i]}  ./${DEST}/${arrRepertoire[$i]}

              if [ "${DEPLACE}" == "1" ]
              then
                effacer  ${fichierEnTraitement}
              fi
            else

              # sig ssdeep sont egales
              logmessage "ERREUR" "ds verif_nom [$?]"
            fi
          else

            # sig ssdeep sont egales
            logmessage "ERREUR" "ds verif_ssd [$?]"
          fi
        else
          # erreur
          logmessage "ERREUR" "ds verif_md5 [$?]"
        fi

      fi


      # info pour debug : ls du fichier post deplacement
      logmessage "INFO" "fin du traitement de [${fichierEnTraitement}] vers [${DEST}/] en : $($ECHO "$(date +%s.%N) - $STARTFICHIER" \
                       | bc) secondes";
      logmessage "INFO" "" "DEBUG_0";

    else
      # on determine qu'il s'agit bien d'un repertoire ou symlink ou d'un fichier indesirable
      # DONC :rien a faire, on passe au suivant
      logmessage "INFO" "il [$fichierEnTraitement] s'agit d'un repertoire, \
          symlink ou fichier indesirable, on passe au prochain element..." "DEBUG_0";

    fi



    let i++
  done

done



# output d'info/debug
logmessage "INFO" ""
logmessage "INFO" ""
logmessage "INFO" "============================================================================================================"
logmessage "INFO" "${nbrTotalFichierRepExamine} elements ont ete examines.";
logmessage "INFO" "\tdont ${nbrRepertoire} repertoires";
logmessage "INFO" "\tdont $(( nbrTotalFichierRepExamine - nbrRepertoire)) fichiers";
logmessage "INFO" "\t\tincluant $((nbrTotalFichierRepExamine - nbrFichierTraites - nbrRepertoire )) rejets/indesirables.";
logmessage "INFO" "${nbrFichierTraites} fichiers ont ete traites.";
# nbrFichierCopie : ne compte pas les fichier doublons : ex si md5-A==md5-b, on ne copie pas
logmessage "INFO" "\tdont ${nbrFichierCopie} qui ont ete copie."
logmessage "INFO" "\tdont $(( nbrFichierTraites - nbrFichierCopie )) qui n'ont pas ete copier car ils existaient deja ds la destination";
logmessage "INFO" "${nbrFichierEfface} fichiers se trouvant deja dans la destination ont ete efface de la source [${SRC}].";
logmessage "INFO" "${nbrFichierRenomme} fichiers ont ete renommer";
logmessage "INFO" "${nbrInfo} messages d'INFO ont ete imprime" "DEBUG_0";
logmessage "INFO" "${nbrAlerte} messages d'ALERTE ont ete signale";
logmessage "INFO" "${nbrErreur} ERREURS ont ete trouvees";
logmessage "INFO" "temps de traitement TOTAL : $($ECHO "$(date +%s.%N) - $STARTGLOBAL" | bc) secondes";



exit;




#if verif_md5() {
#       effacer()
#     }
#     else{
#       if verif_ssd() {
#            effacer()
#         }
#         else{
#            if verif_nom() {
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
