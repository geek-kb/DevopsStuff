#!/usr/bin/env python
# -*- coding: utf-8 -*-
from tempfile import mkstemp, mkdtemp
import public

__all__ = ["TMPDIR"]


@public.add
def tempfile():
    """create temp file and return path"""
    return mkstemp()[1]


@public.add
def tempdir():
    """create temp dir and return path"""
    return mkdtemp()
