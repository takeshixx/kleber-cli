#!/usr/bin/env python3
import sys
import os
import logging
import argparse

from . import __version__
from .client import KleberClient

verbose_log_format = '[%(filename)s:%(lineno)s - %(funcName)20s() ] %(message)s'

LOGGER = logging.getLogger()
ARGS = argparse.ArgumentParser(description='Kleber CLI',
                               formatter_class=argparse.RawDescriptionHelpFormatter)
ARGS.add_argument('infile', default=None, metavar='filename',
                  help='file name or - for STDIN', nargs='?')
ARGS.add_argument('-l', '--list', action='store_true', dest='cmd_list',
                  default=False, help='list pastes/files')
ARGS.add_argument('-n', '--name', action='store', dest='name', metavar='name',
                  default='', help='name for the uploaded file/paste')
ARGS.add_argument('-s', '--secure', action='store_true', dest='secure_url',
                  default=False, help='use a longer, secure URL')
ARGS.add_argument('-p', '--password', action='store', dest='password', metavar='password',
                  default='', help='password for the file/paste')
ARGS.add_argument('-t', '--lifetime', action='store', dest='lifetime', metavar='lifetime',
                  type=int, default=604800, help='lifetime of the uploaded file/paste (default: 604800)')
ARGS.add_argument('-d', '--clipboard', action='store_true', dest='clipboard',
                  default=False, help='add document link to clipboard')
ARGS.add_argument('-c', '--config', action='store', dest='config_file', metavar='filename',
                  default='', help='provide a custom config file (default: ~/.kleberrc)')
ARGS.add_argument('-o', '--page', action='store', dest='list_page', metavar='page',
                  type=int, default=1, help='pagination page (default: 1)')
ARGS.add_argument('-v', '--verbose', action='count', dest='level',
                  default=0, help='verbose logging (repeat for more verbosity)')
ARGS.add_argument('--version', action='store_true', dest='version',
                  default=False, help='print the current version')


def main():
    args = ARGS.parse_args()
    log_format = verbose_log_format if args.level > 0 else '%(message)s'
    levels = [logging.INFO, logging.WARN, logging.DEBUG]
    logging.basicConfig(level=levels[min(args.level, len(levels) - 1)], format=log_format)
    if args.cmd_list:
        kleber = KleberClient()
        upload_list = kleber.list(page=args.list_page)
        print(upload_list)
    elif args.version:
        print(__version__)
    elif args.infile:
        if args.config_file and os.path.isfile(args.config_file):
            kleber = KleberClient(rc_file=args.config_file)
        else:
            kleber = KleberClient()
        url = kleber.upload(args.infile, name=args.name, password=args.password,
                            secure=args.secure_url, lifetime=args.lifetime)
        if args.clipboard:
            try:
                import pyperclip
            except ImportError:
                LOGGER.warning('pyperclip module is not installed')
            else:
                pyperclip.copy(url)
        LOGGER.info(url)
    else:
        ARGS.print_help()


if __name__ == '__main__':
    sys.exit(main())