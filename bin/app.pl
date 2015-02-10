#!/usr/bin/perl

use Dancer2;
use lib path(dirname(__FILE__), '../lib');
use Dancr;
Dancr->to_app;
dance;
