#!/usr/bin/env bash


main() {
    get_commandline_args $@
    check_mandatory_args
    if [[ $INIT == "True" ]]; then
        initialize_token
    fi
    write_key_to_token
}


get_commandline_args() {
    while getopts ":c:dik:l:n:p:s:t:v" opt; do
      case $opt in
        c) CERT=$OPTARG;;
        d) DRYRUN='True'; verbose="True";;
        k) PRIVKEY=$OPTARG;;
        i) INIT='True';;
        l) CERTLABELOPT="--label $OPTARG";;
        n) TOKENLABEL=$OPTARG;;
        p) PKCS11_CARD_DRIVER=$OPTARG;;
        s) SOPIN=$OPTARG;;
        t) USERPIN=$OPTARG;;
        v) verbose="True";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


check_mandatory_args() {
    [ -z "$CERT" ] && usage && echo "missing option -c" && exit 0
    [ -z "$PRIVKEY" ] && usage && echo "missing option -k" && exit 0
    [ -z "$TOKENLABEL" ] && usage && echo "missing option -n" && exit 0
    [ -z "$SOPIN" ]  && ! $INIT  && usage && echo "option -s required with -i" && exit 0
    [ -z "$USERPIN" ] && usage && echo "missing option -t" && exit 0
}


usage() {
    cat << EOF
        Transfer certificate + private key to PKCS#11 Token
        usage: $0 [-i] [-l <label> ] -n <Token Name> [-p <PKCS#11 driver>] [-s <SO PIN>] -t <User PIN> [-v]
          -c  Certifiate file
          -d  Dry run: print commands but do not execute
          -h  print this help text
          -i  initialize token before writing key
          -k  Private key file
          -l  Certificate/private key label
          -n  Token label
          -s  Security Officer PIN
          -p  Path to library of PKCS#11 driver (default: $PKCS11_CARD_DRIVER)
          -t  User PIN
          -v  verbose
EOF
}


initialize_token() {
    echo 'Initializing Token'
    cmd="pkcs11-tool --module $PKCS11_CARD_DRIVER --init-token --label $TOKENLABEL --pin $USERPIN --so-pin $SOPIN"
    run_command
    echo 'Initializing User PIN'
    cmd="pkcs11-tool --module $PKCS11_CARD_DRIVER --login --init-pin --pin $USERPIN --so-pin $SOPIN"
    run_command
}


write_key_to_token() {
    echo 'writing certificate'
    cmd="pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN -w $CERT --type cert $CERTLABELOPT"
    run_command
    echo 'writing private key'
    cmd="pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN -w $PRIVKEY --type privkey $CERTLABELOPT"
    run_command
    echo 'Checking objects on card'
    cmd="pkcs11-tool --module $PKCS11_CARD_DRIVER --login -O --pin $USERPIN"
    run_command
}


run_command() {
    if [ $verbose ]; then
        echo $cmd; echo
    fi
    if [ ! $DRYRUN ]; then
        $cmd
    fi
}

main $@