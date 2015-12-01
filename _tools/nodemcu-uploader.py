#!/usr/bin/env python
# Copyright (C) 2015 Peter Magnusson
# Modified by KillerGoldFisch 2015-05-15
# Version 1.00.001

# For NodeMCU version 0.9.4 build 2014-12-30 and newer.

import os
import serial
import sys
import argparse
import time
import logging

try:
    import Colorer
except:
    pass

log = logging.getLogger(__name__)

class UploadException(Exception):
    """docstring for UploadException"""
    def __init__(self, arg):
        super(UploadException, self).__init__(arg)
        self.arg = arg
        

def read(s, expect =">", timeout=5.0):
    data = ""
    end_time = time.time() + timeout
    while not expect in data and time.time() < end_time:
        time.sleep(0.0005)
        if time.time() > end_time:
            raise UploadException('Timed out. Data so far: ' + repr(data))
        data += s.read(s.inWaiting())
    return data


def read_in_chunks(file_object, chunk_size=1024):
    """Lazy function (generator) to read a file piece by piece.
    Default chunk size: 1k."""
    while True:
        data = file_object.read(chunk_size)
        if not data:
            break
        yield data

def toDec(s):
    return ''.join(("\\"+str(ord(c)) for c in s))

def w(s, data):
    s.write(data + '\r\n')
    s.flush()
    #time.sleep(0.002 * len(data) + 0.0)
    log.debug("-> '{0}'".format(repr(data)))
    rdata = read(s)
    log.debug("<- '{0}'".format(repr(rdata)))
    if  'unexpected symbol' in rdata or \
        'NodeMCU' in rdata or \
        'stdin' in rdata or \
        not data in rdata:
        raise UploadException("Responce: " + repr(rdata))

def write_file(f, d, s):
    d=f.replace("\\", "/")
    log.info("Uploading '{0}'".format(d))
    attempt = 1
    while attempt < 8:
        attempt += 1
        try:
            #w(s, "\n")
            w(s, 'w = nil')
            w(s, "collectgarbage();")
            w(s, 'file.remove("{0}");'.format(d))
            w(s, 'file.remove("{0}.lc");'.format(".".join(d.split('.')[:-1])))
            #time.sleep(0.2)
            w(s, 'file.open("{0}","w+");'.format(d))
            #time.sleep(0.2)
            w(s, 'w = file.write')
            size = float(os.path.getsize(f))
            written = 0
            file_object = open(f, 'rb')
            for chunk in read_in_chunks(file_object, 10):
                #print repr(chunk)
                w(s, "w('{0}');".format(toDec(chunk)))
                written += len(chunk)
                log.info("Progress: {0:.1f}%".format(100.0*written/size))
            #w(s, 'file.remove("{0}");'.format(d))
            w(s, 'file.close();')
            w(s, 'w = nil;')
            w(s, "collectgarbage();")

            if f.endswith(".lua") and f != "init.lua":
                time.sleep(0.1)
                log.info("Compile...")
                w(s, 'file.compile("{0}");'.format(d))
                w(s, 'file.remove("{0}");'.format(d))

            time.sleep(0.1)
            return
        except UploadException, ex:
            log.warn("Exception while uploading File '{0}': {1}".format(f, ex))
            #log.info("Reset NodeNMU")
            #w(s, 'node.restart()')
            time.sleep(1.0)
    #log.error("Give up Uploading '{0}'".format(f))
    raise Exception("Upload not possible!")

def arg_auto_int(x):
    return int(x, 0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description = 'NodeMCU Lua file uploader', prog = 'nodemcu-uploader')
    parser.add_argument(
            '--verbose',
            help = 'verbose output',
            action = 'store_true',
            default = False)

    parser.add_argument(
            '--port', '-p',
            help = 'Serial port device',
            default = "COM5")

    parser.add_argument(
            '--baud', '-b',
            help = 'Serial port baudrate',
            type = arg_auto_int,
            default = 9600)

    subparsers = parser.add_subparsers(
        dest='operation',
        help = 'Run nodemcu-uploader {command} -h for additional help')

    upload_parser = subparsers.add_parser(
            'upload',
            help = 'Path to one or more files to be uploaded. Destination name will be the same as the file name.')

    # upload_parser.add_argument(
    #         '--filename', '-f',
    #         help = 'File to upload. You can specify this option multiple times.',
    #         action='append')

    # upload_parser.add_argument(
    #         '--destination', '-d',
    #         help = 'Name to be used when saving in NodeMCU. You should specify one per file.',
    #         action='append')

    upload_parser.add_argument('filename', nargs='+', help = 'Lua file to upload. Use colon to give alternate destination.')

    upload_parser.add_argument(
            '--compile', '-c',
            help = 'If file should be uploaded as compiled',
            action='store_true',
            default=False
            )
    
    upload_parser.add_argument(
            '--verify', '-v',
            help = 'To verify the uploaded data.',
            action='store_true',
            default=False
            )
    
    upload_parser.add_argument(
            '--restart', '-r',
            help = 'If esp should be restarted',
            action='store_true',
            default=False
    )

    download_parser = subparsers.add_parser(
            'download',
            help = 'Path to one or more files to be downloaded. Destination name will be the same as the file name.')

    # download_parser.add_argument(
    #         '--filename', '-f',
    #         help = 'File to download. You can specify this option multiple times.',
    #         action='append')

    # download_parser.add_argument(
    #         '--destination', '-d',
    #         help = 'Name to be used when saving in NodeMCU. You should specify one per file.',
    #         action='append')

    download_parser.add_argument('filename', nargs='+', help = 'Lua file to download. Use colon to give alternate destination.')


    file_parser = subparsers.add_parser(
        'file',
        help = 'File functions')

    file_parser.add_argument('cmd', choices=('list', 'do', 'format'))
    file_parser.add_argument('filename', nargs='*', help = 'Lua file to run.')

    node_parse = subparsers.add_parser(
        'node', 
        help = 'Node functions')

    node_parse.add_argument('ncmd', choices=('heap', 'restart'))


    args = parser.parse_args()

    formatter = logging.Formatter('%(message)s')
    logging.basicConfig(level=logging.INFO, format='%(message)s')

    if args.verbose:
        log.setLevel(logging.DEBUG)

    uploader = serial.Serial(args.port, args.baud)

    if args.operation == 'upload' or args.operation == 'download':
        sources = args.filename
        destinations = []
        for i in range(0, len(sources)):
            sd = sources[i].split(':')
            if len(sd) == 2:
                destinations.append(sd[1])
                sources[i]=sd[0]
            else:
                destinations.append(sd[0])

        if args.operation == 'upload':
            if len(destinations) == len(sources):
                #uploader.prepare()
                for f, d in zip(sources, destinations):
                    #uploader.write_file(f, d, args.verify)
                    write_file(f, d, uploader)
                    if args.compile:
                        pass
                        #uploader.file_compile(d)
                        #uploader.file_remove(d)
            else:
                raise Exception('You must specify a destination filename for each file you want to upload.')

            if args.restart:
                pass #uploader.node_restart()
            log.info('All done!')

        if args.operation == 'download':
            if len(destinations) == len(sources):
                for f, d in zip(sources, destinations):
                    pass #uploader.read_file(f, d)
            else:
                raise Exception('You must specify a destination filename for each file you want to download.')
            log.info('All done!')

    elif args.operation == 'file':
        if args.cmd == 'list':
            pass #uploader.file_list()
        if args.cmd == 'do':
            for f in args.filename:
                pass #uploader.file_do(f)
        elif args.cmd == 'format':
            pass #uploader.file_format()
    
    elif args.operation == 'node':
        if args.ncmd == 'heap':
            pass #uploader.node_heap()
        elif args.ncmd == 'restart':
            pass #uploader.node_restart()

    #uploader.close()