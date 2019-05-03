import inspect
import os
import subprocess
import sys
from pathlib import Path

import pytest
''' Test with PKCS11 device. If SOFTHSM is set and the configured HSM device is not found, fall back to SoftHSM 
    Test pattern with command-lie interface: invoke shell script with same name (-> inspect.stack()[0][3]) as subprocess.
    This allows for 1:1 testablity of bash-level commands and pytest
'''

if sys.version_info[0] < 3:
    raise Exception("Must be using Python 3")

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
    copy_env_key(test_env, 'HSMLABEL')
    copy_env_key(test_env, 'JAVA_HOME')
    copy_env_key(test_env, 'LOGLEVEL')
    copy_env_key(test_env, 'PKCS11USBDEVICE')
    copy_env_key(test_env, 'PKCS11LIBDEVICE')
    copy_env_key(test_env, 'P11KIT_DESC')
    copy_env_key(test_env, 'PYKCS11LIB')
    copy_env_key(test_env, 'PKCS11_CARD_DRIVER')
    copy_env_key(test_env, 'PYKCS11PIN')
    copy_env_key(test_env, 'SOPIN')
    copy_env_key(test_env, 'SOFTHSM')
    copy_env_key(test_env, 'LOGDIR')
    if test_env['PKCS11LIBDEVICE'].startswith('eToken'):
        test_env['testproc'] = 'eToken'
    elif test_env['PKCS11LIBDEVICE'] == 'Nitrokey.Pro':
        test_env['testproc'] = 'OpenPGPCard'
    return test_env


@pytest.mark.hsm
@pytest.mark.smartcard
def test_detect_PKCS11_USB_device(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed with code = ' + str(rc))


@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsm
def test_pkcs11_env_settings(testenv):
    assert testenv['HSMLABEL']
    assert testenv['PYKCS11LIB']
    assert Path(testenv['PYKCS11LIB']).is_file()
    assert testenv['PKCS11_CARD_DRIVER']
    assert Path(testenv['PKCS11_CARD_DRIVER']).is_file()
    assert testenv['PYKCS11PIN']
    assert testenv['SOPIN']


@pytest.mark.hsm
@pytest.mark.smartcard
def test_pkcs11_env_settings_hsm(testenv):
    assert testenv['PKCS11USBDEVICE']
    assert testenv['PKCS11LIBDEVICE']


@pytest.mark.hsm
@pytest.mark.smartcard
def test_pcscd_up():
    rc = subprocess.call(['/usr/sbin/pidof', '/usr/sbin/pcscd'], shell=False)
    assert rc == 0, ('/usr/sbin/pcscd not running')

@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsm
def test_list_pkcs11_token_slots(testenv):
    cmd = ['/usr/bin/pkcs11-tool', '--module', testenv['PYKCS11LIB'], '--list-token-slots']
    rc = subprocess.call(cmd, shell=False, env=testenv)
    assert rc == 0, (cmd + ' failed. ERROR: HSM Token not connected')


@pytest.mark.hsm
@pytest.mark.softhsm
def test_initialize_token(testenv):
    cmd = ['/usr/bin/pkcs11-tool', '--module', testenv['PYKCS11LIB'],
           '--init-token', '--label', testenv['HSMLABEL'], '--so-pin', testenv['SOPIN'],
    ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    assert rc == 0, (cmd + f" failed. HSM Token not initialized, {cmd[0]} failed with code " + str(rc))


@pytest.mark.smartcard
def test_erase_token(testenv):
    cmd = ['/usr/bin/openpgp-tool', '--erase']
    rc = subprocess.call(cmd, shell=False, env=testenv)
    assert rc == 0, (cmd + f" failed. HSM Token not initialized, rc " + str(rc))


@pytest.mark.hsm
@pytest.mark.softhsm
def test_initialize_user_pin(testenv):
    cmd = ['/usr/bin/pkcs11-tool', '--module', testenv['PYKCS11LIB'],
           '--init-pin', '--login', '--pin', testenv['PYKCS11PIN'], '--so-pin', testenv['SOPIN'],
           ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    assert rc == 0, (cmd + ' failed. User PIN not initialized, pkcs11-tool returned ' + str(rc))


@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsm
def test_user_login(testenv):
    cmd = ['/usr/bin/pkcs11-tool', '--module', testenv['PYKCS11LIB'],
           '--show-info', '--login', '--pin', testenv['PYKCS11PIN'],
    ]
    rc = subprocess.call(cmd, shell=False, env=testenv)
    assert rc == 0, (cmd + ' failed. Could not login to token.')


@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsm
def test_create_swcert(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    if rc:
        raise Exception(inspect.stack()[0][3] + ' failed with code = ' + str(rc))
    assert Path('/ramdisk', 'testcert_crt.der').is_file()
    assert Path('/ramdisk', 'testcert_key.der').is_file()


@pytest.mark.hsm
@pytest.mark.softhsm
def test_pkcs11tool_upload_cert(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')  # shell script name == function name + ext
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed with code = ' + str(rc))


@pytest.mark.hsm
@pytest.mark.softhsm
def test_list_certificates_on_hsm(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed. No certificate found.')


@pytest.mark.hsm
@pytest.mark.softhsm
def test_list_private_keys_on_hsm(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed. No key found.')


@pytest.mark.hsm
@pytest.mark.smartcard
# softhsm does not support signing
def test_sign_with_hsm(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed with code = ' + str(rc))


@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsms
def test_gnu_p11tool_list_all(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed with code = ' + str(rc))


@pytest.mark.hsm
@pytest.mark.smartcard
@pytest.mark.softhsm
def test_pyff(shellscriptdir, testenv):
    s = shellscriptpath(shellscriptdir, inspect.stack()[0][3] + '.sh')
    rc = subprocess.call([s], shell=True, env=testenv)
    assert rc == 0, (s + ' failed with code = ' + str(rc))
