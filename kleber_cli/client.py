import sys
import os
import io
import logging
import requests
import json
import progressbar
import requests_toolbelt

from . import __version__

LOGGER = logging.getLogger()


class KleberClient(object):
    def __init__(self, api_key=None, rc_file=None):
        self.url = 'https://kleber.io'
        self.user_agent = 'Kleber CLI ' + __version__
        self.max_size = 262144000
        self.upload_lifetime = 604800
        self.api_key = api_key
        if rc_file:
            self.rc_file = rc_file
        else:
            self.rc_file = os.path.expanduser('~') + '/.kleberrc'
        if not api_key:
            self._read_rc_file()
        self.name = ''
        self.password = ''
        self.secure = False
        self.api_url = self.url + '/api'
        self.uploads_url = self.api_url + '/uploads/'
        self.files_url = self.api_url + '/files/'
        self.headers = {'User-Agent': self.user_agent,
                        'Authorization': 'Token ' + self.api_key}

    def _read_rc_file(self):
        """Read configuration values from the
        rc file, i.e. the API key."""
        local_rc_file = os.path.dirname(os.path.abspath(__file__)) + '/.kleberrc'
        if os.path.isfile(local_rc_file):
            self.rc_file = local_rc_file
        with open(self.rc_file) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                LOGGER.error('Invalid data in ' + self.rc_file)
                sys.exit(1)
            else:
                if 'api_key' in data.keys():
                    self.api_key = data['api_key']
        if not self.api_key:
            LOGGER.error('Could not load api_key from ' + self.rc_file)
            sys.exit(1)

    def upload(self, file_name, name='', password='', secure=False,
               lifetime=None):
        """Upload a file.

        :param file_name: the path to the file that should be uploaded
        :param name: the name of the upload
        :param password: a password for the upload
        :param secure: if True, use a secure URL (a longer shortcut)
        :param lifetime: a positive int that determines the lifetime
                         of an uploaded file/paste in seconds.
        """
        if file_name == '-':
            try:
                stdin = sys.stdin.buffer
            except AttributeError:
                stdin = sys.stdin
            content = stdin.read()
            file_reader = io.BytesIO(content)
        elif os.path.isfile(file_name):
            file_reader = open(file_name, 'rb')
        else:
            LOGGER.error('Invalid input: ' + file_name)
            sys.exit(1)
        if name:
            upload_file = (name, file_reader)
        else:
            upload_file = (file_name, file_reader)
        if lifetime:
            try:
                self.upload_lifetime = str(int(lifetime))
            except ValueError:
                LOGGER.error('Invalid lifetime value: ' + lifetime)
                sys.exit(1)
        files = {'uploaded_file': upload_file}
        data = {'lifetime': str(self.upload_lifetime),
                'secure_shortcut': str(secure).lower()}
        if password:
            data['password'] = password

        def callback(monitor):
            progress.update(monitor.bytes_read)

        fields_dict = data.copy()
        fields_dict.update(files)
        enc = requests_toolbelt.multipart.encoder.MultipartEncoder(fields=fields_dict)
        widgets = [progressbar.DataSize(),
                   ' /',
                   progressbar.DataSize('max_value'),
                   ' (',
                   progressbar.Percentage(),
                   ') |',
                   progressbar.FileTransferSpeed(),
                   ' ',
                   progressbar.Bar(),
                   ' ',
                   progressbar.Timer()]
        progress = progressbar.ProgressBar(max_value=enc.len, filled_char='=',
                                           widgets=widgets).start()
        m = requests_toolbelt.multipart.encoder.MultipartEncoderMonitor(enc, callback)
        self.headers['Content-Type'] = m.content_type
        resp = requests.post(self.files_url, headers=self.headers,
                             data=m, stream=True)
        progress.finish()
        if resp.status_code == 201:
            upload_url = self.url + '/' + resp.json()['shortcut']
            if password:
                upload_url = upload_url + '?password=' + password
            return upload_url
        else:
            LOGGER.error('Failed to upload file (' + str(resp.status_code) + ')')
            sys.exit(1)

    def list(self, page=1):
        """List the upload history of the current user."""
        history_url = self.uploads_url + '?page=' + str(page)
        resp = requests.get(history_url, headers=self.headers)
        if not resp.status_code == 200:
            LOGGER.error('Request to API failed (' + str(resp.status_code) + ')')
            return
        output = json.dumps(resp.json(), indent=2, sort_keys=True)
        return output
