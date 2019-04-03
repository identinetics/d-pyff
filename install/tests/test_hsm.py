import inspect
import os
import subprocess
from pathlib2 import Path

import pytest

@pytest.fixture()
def shellscriptdir():
    return Path(__file__).parent / 'shellscripts'

def shellscriptpath(dir, filename):
    return str(Path(dir) / filename)

def copy_env_key(new_env, key):
    new_env[key] = os.environ.get(key, '')

@pytest.fixture()
def testenv():
    test_env = {}
    copy_env_key(test_env, 'HSMUSBDEVICE')
    copy_env_key(test_env, 'HSMP11DEVICE')
    copy_env_key(test_env, 'P11KIT_DESC')
    copy_env_key(test_env, 'PYKCS11LIB')
    copy_env_key(test_env, 'PKCS11_CARD_DRIVER')
    copy_env_key(test_env, 'PYKCS11PIN')
    copy_env_key(test_env, 'SOPIN')
    copy_env_key(test_env, 'SOFTHSM')
    copy_env_key(test_env, 'LOGDIR')
    copy_env_key(test_env, 'LOGFILE')
    return test_env


def test_detect_HSM_USB_device(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed with code = ' + str(rc))


def test_pkcs11_env_settings(testenv):
    assert testenv['PYKCS11LIB']
    assert Path(testenv['PYKCS11LIB']).is_file()
    assert testenv['PYKCS11PIN']
    assert testenv['SOPIN']
    assert testenv['HSMUSBDEVICE']
    assert testenv['HSMP11DEVICE']


def test_pcscd_up():
    rc = subprocess.call(['/usr/sbin/pidof', '/usr/sbin/pcscd'], shell=False)
    if rc:
        raise Exception('/usr/sbin/pcscd not running')


def test_list_pkcs11_token_slots(testenv):
    cmd = ['/usr/bin/pkcs11-tool',
           '--module', testenv['PYKCS11LIB'],
           '--list-token-slots',
    ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. ERROR: HSM Token not connected')


def test_initialize_hsm_token(testenv):
    cmd = ['/usr/bin/pkcs11-tool',
           '--module', testenv['PYKCS11LIB'],
           '--init-token',
           '--label', 'test',
           '--so-pin', testenv['SOPIN'],
    ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. HSM Token not initialized, failed with code ' + str(rc))


def test_initialize_user_pin(testenv):
    cmd = ['/usr/bin/pkcs11-tool',
           '--module', testenv['PYKCS11LIB'],
           '--init-pin',
           '--login', '--pin', testenv['PYKCS11PIN'],
           '--so-pin', testenv['SOPIN'],
           ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. User PIN not initialized, failed with code ' + str(rc))


def test_test_user_login(shellscriptdir, testenv):
    cmd = ['/usr/bin/pkcs11-tool',
           '--module', testenv['PYKCS11LIB'],
           '--show-info',
           '--login', '--pin', testenv['PYKCS11PIN'],
    ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. Could not login to token.')


def test_create_and_upload_cert(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed with code = ' + str(rc))
    assert Path('/ramdisk', 'testcert_crt.der').is_file()
    assert Path('/ramdisk', 'testcert_key.der').is_file()


def test_list_certificates_on_hsm(shellscriptdir, testenv):
    #cmd = ['/usr/bin/pkcs11-tool',
    #       '--module', testenv['PYKCS11LIB'],
    #       '--list-objects', '--type', 'cert',
    #       '--login', '--pin', testenv['PYKCS11PIN'],
    #       '|', 'grep', 'Certificate Object"',
    #       ]
    #rc = subprocess.call(cmd, shell=False, env=testenv)
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. No certificate found.')


def test_list_private_keys_on_hsm(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed. No key found.')


def test_sign_with_hsm(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed with code = ' + str(rc))


