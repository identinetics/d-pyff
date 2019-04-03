#!/bin/bash

pkcs11-tool --module $PYKCS11LIB --init-token --label test --so-pin $SOPIN
