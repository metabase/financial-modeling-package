import json
from hashlib import md5
from pathlib import Path
from time import time

import requests


class MetabaseClient:
    SESSION_FILE_PREFIX = '/tmp/metabase.session-'
    COOKIE_FILE_PREFIX = '~/.metabase.cookie-'  # Durable path

    def __init__(self, metabase_url, user, password, api_key=None):
        if not metabase_url.startswith('https://'):
            raise ValueError('Metabase URL must start with https://')

        if not metabase_url.endswith('/'):
            metabase_url += '/'

        self.metabase_url = metabase_url
        self.user = user
        self.password = password
        self.api_url = metabase_url + 'api/'
        self.api_key = api_key

    @property
    def id(self) -> str:
        return md5((self.api_url + self.user + self.password).encode()).hexdigest()

    @property
    def _cookie_file(self) -> Path:
        return Path(self.COOKIE_FILE_PREFIX + self.id).expanduser()

    @property
    def _cookies(self) -> dict:
        return json.load(self._cookie_file.open()) if self._cookie_file.exists() else {}

    def _save_cookies(self, cookies: requests.cookies.RequestsCookieJar):
        # Save metabase.DEVICE to avoid new device security alert for new session
        # It is only set for new device, so check key before saving.
        if 'metabase.DEVICE' not in cookies:
            return

        print('Saving cookies to', self._cookie_file)
        with self._cookie_file.open('w') as fh:
            cookies_dict = cookies.get_dict()
            cookies_dict.pop('metabase.SESSION', None)  # It won't be updated if saved
            json.dump(cookies_dict, fh)

    @property
    def _session_file(self) -> str:
        return Path(self.SESSION_FILE_PREFIX + self.id)

    def session(self) -> str:
        # Metabase's session expires after 14 days, so we renew every 10 days
        if not self._session_file.exists() or self._session_file.stat().st_mtime < (time() - 864000):
            print('Caching session to', self._session_file)
            with self._session_file.open('w') as fp:
                s = self.post('session', json={'username': self.user, 'password': self.password}, skip_session=True)
                fp.write(s['id'])

        return self._session_file.open().read()

    def headers(self, skip_session=False):
        heads = {
            'Content-Type': 'application/json',
        }

        if self.api_key:
            heads['X-Metabase-APIKey'] = self.api_key

        if not skip_session:
            heads['X-Metabase-Session'] = self.session()

        return heads

    def get(self, path, *args, **kwargs):
        """
        Makes a GET request to the Metabase API endpoint for the given path

        :param str path: The path to make the request to. E.g. permissions/group
        :return: JSON response object for the given path
        """
        resp = requests.get(self.api_url + path, *args, **kwargs, headers=self.headers())
        resp.raise_for_status()
        return resp.json()

    def put(self, path, *args, **kwargs):
        """
        Makes a PUT request to the Metabase API endpoint for the given path

        :param str path: The path to make the request to. E.g. user
        :return: JSON response object for the given path
        """
        resp = requests.put(self.api_url + path, *args, **kwargs, headers=self.headers())
        resp.raise_for_status()
        return resp.json()

    def post(self, path: str, skip_session: bool = False, skip_return: bool = False, *args, **kwargs):
        """
        Makes a POST request to the Metabase API endpoint for the given path

        :param path: The path to make the request to. E.g. session
        :param skip_session: Skip creating a new session
        :param skip_return: Skip returning response
        :return: JSON response object for the given path
        """
        resp = requests.post(self.api_url + path, *args, **kwargs, headers=self.headers(skip_session=skip_session),
                             cookies=self._cookies)
        resp.raise_for_status()

        if skip_session:
            self._save_cookies(resp.cookies)

        if not skip_return:
            return resp.json()
