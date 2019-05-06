#!/usr/bin/env python

from __future__ import print_function
from PyKCS11 import *
from PyKCS11.LowLevel import *
import sys



class GetInfo(object):
    def colorize(self, text, arg):
        print(text, arg)

    def display(self, obj, indent=""):
        dico = obj.to_dict()
        for key in sorted(dico.keys()):
            type = obj.fields[key]
            left = indent + key + ":"
            if type == "flags":
                self.colorize(left, ", ".join(dico[key]))
            elif type == "pair":
                self.colorize(left, "%d.%d" % dico[key])
            else:
                self.colorize(left, dico[key])

    def __init__(self, lib=None):
        self.pkcs11 = PyKCS11Lib()
        self.pkcs11.load(lib)

    def getSlotInfo(self, slot):
        print("Slot n.:", slot)
        self.display(self.pkcs11.getSlotInfo(slot), " ")

    def getTokenInfo(self, slot):
        print("TokenInfo")
        self.display(self.pkcs11.getTokenInfo(slot), "  ")

    def getInfo(self):
        self.display(self.pkcs11.getInfo())

    def getSessionInfo(self, slot, pin=""):
        print("SessionInfo", end=' ')
        self.session = self.pkcs11.openSession(slot)
        if pin == "":
            print("PIN missing")
            sys.exit(2)
        else:
            print("Logging in with PIN=" + pin)
            try:
                self.session.login(pin)
            except:
                print("login failed, exception: ", str(sys.exc_info()[1]))
        self.display(self.session.getSessionInfo(), "  ")

    def dumpattr(self, obj):
        attributes = {
            "CKA_CLASS": [CKA_CLASS, 'key'],
            "CKA_END_DATE": [CKA_END_DATE, 'str'],
            "CKA_EXTRACTABLE": [CKA_EXTRACTABLE, 'bool'],
            "CKA_ID": [CKA_ID, 'str'],
            "CKA_ISSUER": [CKA_ISSUER, 'str'],
            "CKA_KEY_TYPE": [CKA_KEY_TYPE, 'key'],
            "CKA_LABEL": [CKA_LABEL, 'str'],
            "CKA_LOCAL": [CKA_LOCAL, 'bool'],
            "CKA_NEVER_EXTRACTABLE": [CKA_NEVER_EXTRACTABLE, 'bool'],
            "CKA_PRIVATE": [CKA_PRIVATE, 'bool'],
            "CKA_SERIAL_NUMBER": [CKA_SERIAL_NUMBER, 'str'],
            "CKA_START_DATE": [CKA_START_DATE, 'str'],
            "CKA_SUBJECT": [CKA_SUBJECT, 'str'],
            "CKA_VALUE": [CKA_VALUE, 'str'],
        }

        for (label, attr_def) in attributes.items():
            attr_key = attr_def[0]
            attr_type = attr_def[1]
            try:
                attr_val = self.session.getAttributeValue(obj, [attr_key], allAsBinary=True)
            except PyKCS11Error as e:
                continue
            if attr_key == CKA_CLASS:
                if attr_val == CKO_CERTIFICATE:
                    print("== Certificate ==")
                elif attr_val == CKO_PRIVATE_KEY:
                    print("== Private Key ==")
            print(label + ': ', attr_val, ', type: ', attr_type)  # TODO: pretty print attribute values


    def getKeyInfo(self):
        label = 'mdsign'
        #template = [(CKA_LABEL, label), (CKA_CLASS, CKO_PRIVATE_KEY), (CKA_KEY_TYPE, CKK_RSA)]
        token_objects = self.session.findObjects()
        print('Reading %s token objects' % len(token_objects))
        i = 1
        for obj in token_objects:
            print("============ Object %s ============" % i)
            self.dumpattr(obj)
            i += 1


def usage():
    print("Usage:", sys.argv[0], end=' ')
    print("[-p pin][--pin=pin] (use 'NULL' for pinpad)", end=' ')
    print("[-s slot][--slot=slot]", end=' ')
    print("[-c lib][--lib=lib]", end=' ')
    print("[-h][--help]")

if __name__ == '__main__':
    import getopt

    try:
        opts, args = getopt.getopt(sys.argv[1:], "p:s:c:ho",
            ["pin=", "slot=", "lib=", "help", "opensession"])
    except getopt.GetoptError:
        # print help information and exit:
        usage()
        sys.exit(2)

    slot = None
    lib = None
    pin = ""
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        if o in ("-p", "--pin"):
            pin = a
            if pin == "NULL":
                pin = None
        if o in ("-s", "--slot"):
            slot = int(a)
        if o in ("-c", "--lib"):
            lib = a

    getInfo = GetInfo(lib)
    getInfo.getInfo()

    slots = getInfo.pkcs11.getSlotList()
    print("Available Slots:", len(slots), slots)

    if len(slots) == 0:
        sys.exit(2)

    print("Using slot 0")
    slot = 0
    try:
        getInfo.getSlotInfo(slot)
        getInfo.getSessionInfo(slot, pin)
        getInfo.getTokenInfo(slot)
        getInfo.getKeyInfo()
        getInfo.session.logout()
    except PyKCS11Error as e:
        print("Error:", e)
