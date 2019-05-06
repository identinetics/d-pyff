#!/usr/bin/env bash

# smoke test for idp disco service - real test would have to drive Javascript

curl 'http://localhost:8080/role/idp.ds?entityID=https://sp5.test.example.org/sp.xml'