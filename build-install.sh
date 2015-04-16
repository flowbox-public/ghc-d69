#!/bin/bash

# setConfigVar :: String -> String -> String -> ()
setConfigVar() {
    varName=$1
    prompt=$2
    varDefault=$3

    if eval [[ -z "\$$varName" ]] ; then
        echo -n "$prompt [default: $varDefault]: "
        read $varName
        if eval [[ -z "\$$varName" ]] ; then
            eval $varName=$varDefault
        fi
    fi
}

# askYesNo :: String -> ()
askYesNo() {
    prompt=$1

    echo -n "$prompt [y/N]: "
    read answer

    accepted=false
    case $answer in
        y | Y | yes | Yes | YES ) accepted=true
    esac

    if [[ "$accepted" != true ]]; then
        echo "Bye!"
        exit 1
    fi
}

# printHeader :: String -> ()
printHeader() {
    header=$1

    echo
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "-   $header"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
}

# check if the required 'patch' utility is installed
type patch  >/dev/null 2>&1 || { echo >&2 "System utility 'patch' required but not found. Install it and try again."; exit 1; }

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

DEFAULT_VERSION="7.8.4"

# go through input arguments and search for flags configuring the build and installation process
for i in "$@"
do
    case $i in
        --prefix=*)
            PREFIX="${i#*=}"
            shift
        ;;
        --jobs=*)
            JOBS="${i#*=}"
            shift
        ;;
        --version=*)
            VERSION="${i#*=}"
            shift
        ;;
        --download-dir=*)
            DOWNLOAD="${i#*=}"
            shift
        ;;
        *)
            shift
        ;;
    esac
done

# check if the version is already set, if not ask the user to provide one
setConfigVar VERSION "Which version would you like to install?" $DEFAULT_VERSION

# check if the download location is already set, if not ask the user to provide one
setConfigVar DOWNLOAD "Where do you want to download the sources to?" "./downloads"

# check if prefix is already set, if not ask the user to provide one
setConfigVar PREFIX "Please provide a location for the installation" "/opt/ghc/$VERSION-d69"

# check if the number of jobs is already set, if not ask the user to provide one
setConfigVar JOBS "Specify the number of jobs to run simultaneously (empty == no limit)"
if [[ -z "$JOBS" ]] ; then
    jobs_limit="no limit"
else
    jobs_limit=$JOBS
fi

# display the configuration and ask for confirmation
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Selected version of GHC:                $VERSION"
echo "Download location:                      $DOWNLOAD"
echo "The patched ghc will be installed in:   $PREFIX"
echo "Number of simultaneous jobs_limit:      $jobs_limit"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
askYesNo "Would you like to continue?"

printHeader "DOWNLOADING GHC..."
wget -P $DOWNLOAD http://downloads.haskell.org/~ghc/$VERSION/ghc-$VERSION-src.tar.xz

printHeader "UNPACKING GHC..."
pushd $DOWNLOAD # push-1
tar xf ghc-$VERSION-src.tar.xz

printHeader "APPLYING THE PATCH..."
pushd ghc-$VERSION  # push-2
echo $SCRIPTPATH/D69_simplified.diff
patch -p1 < $SCRIPTPATH/D69_simplified.diff

printHeader "CONFIGURING GHC..."
./configure --prefix="$PREFIX"

printHeader "BUILDING GHC..."
echo "make -j$JOBS"
make -j$JOBS

printHeader "INSTALLING GHC..."
make install || sudo -p "Seems you need to have root privileges in order to continue. Please provide the password for sudo: " make install

popd # push-2
popd # push-1
