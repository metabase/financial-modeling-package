from unittest.mock import Mock

from utils.fs import in_temp_dir
from requests.cookies import RequestsCookieJar

from data_products.metabase_client import MetabaseClient


def test_id():
    assert MetabaseClient('https://url', 'user', 'password').id == '0dfb753725ab6b1395d226ae109c416a'
    assert MetabaseClient('https://url-updated', 'user', 'password').id == '076e681e77a79f2cf4522a63ec3a1399'
    assert MetabaseClient('https://url', 'user-updated', 'password').id == 'fd3b93675bc95279cb1bae1198f65701'
    assert MetabaseClient('https://url', 'user', 'password-updated').id == 'd49b75190ecf881da3c2031eff5dbda7'


def test_session(mock_request, monkeypatch):
    cookies = RequestsCookieJar()
    cookies.set('metabase.DEVICE', '1-2-3')
    cookies.set('metabase.SESSION', 'should not save, nor used later')
    mock_request.return_value = Mock(json=Mock(side_effect=[{'id': 'session id'}, {'id': 'new session id'}]),
                                     cookies=cookies)

    with in_temp_dir():
        monkeypatch.setattr(MetabaseClient, 'SESSION_FILE_PREFIX', 'metabase-session-')
        monkeypatch.setattr(MetabaseClient, 'COOKIE_FILE_PREFIX', 'metabase-cookie-')

        # 1st call will creae new session
        session = MetabaseClient('https://url/', 'user', 'password').session()

        mock_request.assert_called_with('post', 'https://url/api/session', data=None,
                                        json={'username': 'user', 'password': 'password'},
                                        headers={'Content-Type': 'application/json'},
                                        cookies={})
        mock_request.reset_mock()
        assert session == 'session id'

        # 2nd call will hit cache
        session = MetabaseClient('https://url/', 'user', 'password').session()
        mock_request.assert_not_called()
        assert session == 'session id'

        # Remove session and it should renew with cookies
        client = MetabaseClient('https://url/', 'user', 'password')
        client._session_file.unlink()
        session = client.session()
        mock_request.assert_called_with('post', 'https://url/api/session', data=None,
                                        json={'username': 'user', 'password': 'password'},
                                        headers={'Content-Type': 'application/json'},
                                        cookies={'metabase.DEVICE': '1-2-3'})  # No SESSION for cookie
        assert session == 'new session id'
