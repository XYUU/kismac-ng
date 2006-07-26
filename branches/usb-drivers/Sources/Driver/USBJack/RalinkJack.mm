/*
 *  RalinkJack.mm
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include "RalinkJack.h"

RalinkJack::RalinkJack() {
    _isEnabled = false;
    _deviceInit = false;
    _devicePresent = false;
    
    _interface = NULL;
    _runLoopSource = NULL;
    _runLoop = NULL;
    _intLoop = NULL;
    _channel = 3;
    _frameSize = 0;
    _notifyPort = NULL;
    
    pthread_mutex_init(&_wait_mutex, NULL);
    pthread_cond_init (&_wait_cond, NULL);
    pthread_mutex_init(&_recv_mutex, NULL);
    pthread_cond_init (&_recv_cond, NULL);
    
    run();
    
    while (_runLoop==NULL || _intLoop==NULL)
        usleep(100);
}

RalinkJack::~RalinkJack() {
    stopRun();
    _interface = NULL;
    _frameSize = 0;
    
    pthread_mutex_destroy(&_wait_mutex);
    pthread_cond_destroy(&_wait_cond);
    pthread_mutex_destroy(&_recv_mutex);
    pthread_cond_destroy(&_recv_cond);
}
