import json
import os
import pathlib
import subprocess
import tempfile
import unittest
import runpy
import re
import io
import sqlite3
import datetime
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/voxtype-panel-backend'

class BackendTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name)
        self.base = self.home / '.config/voxtype'
        self.base.mkdir(parents=True)
    def call(self, data):
        env = dict(os.environ, HOME=str(self.home))
        output = subprocess.check_output([str(SCRIPT)], input=json.dumps(data), text=True, env=env)
        return json.loads(output)
    def test_prompt_and_profile(self):
        self.assertTrue(self.call({'action':'prompt','profile':'code','text':'保留原意'})['ok'])
        self.assertEqual(json.loads((self.base/'prompts.json').read_text())['code'], '保留原意')
        self.assertTrue(self.call({'action':'profile','value':'chat'})['ok'])
        self.assertEqual((self.base/'active-profile').read_text().strip(), 'chat')
        self.assertFalse(self.call({'action':'profile','value':'other'})['ok'])
    def test_postprocess_can_be_disabled_and_preserves_text(self):
        self.assertFalse(self.call({'action':'postprocess','enabled':'false'})['ok'])
        self.assertTrue(self.call({'action':'postprocess','enabled':False})['ok'])
        env=dict(os.environ,HOME=str(self.home))
        text='原始转写\n  保留空白\n'
        result=subprocess.run([str(SCRIPT.parent/'voxtype-deepseek')],input=text,text=True,capture_output=True,env=env,check=True)
        self.assertEqual(result.stdout,text)
        self.assertEqual(result.stderr,'')
        self.assertFalse((self.base/'history.sqlite3').exists())
        self.assertTrue(self.call({'action':'postprocess','enabled':True})['ok'])
        self.assertEqual((self.base/'postprocess-enabled').read_text().strip(),'1')

    def test_custom_profile_creation_and_selection(self):
        (self.base/'prompts.json').write_text(json.dumps({'general':'原始提示词'}))
        result=self.call({'action':'add_profile','name':'会议纪要'})
        self.assertTrue(result['ok'])
        ident=result['data']['id']
        self.assertEqual((self.base/'active-profile').read_text().strip(),ident)
        self.assertEqual(json.loads((self.base/'prompts.json').read_text())[ident], '原始提示词')
        self.assertTrue(self.call({'action':'prompt','profile':ident,'text':'整理会议'})['ok'])
        self.assertTrue(self.call({'action':'profile','value':ident})['ok'])
        self.assertFalse(self.call({'action':'add_profile','name':'会议纪要'})['ok'])
        self.assertFalse(self.call({'action':'add_profile','name':'<img>'})['ok'])
        env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.home/'.config'))
        helper=SCRIPT.parent/'voxtype-profile'
        subprocess.run([str(helper),'set',ident],env=env,check=True)
        self.assertEqual(subprocess.check_output([str(helper),'get'],env=env,text=True).strip(),ident)

    def test_profile_rename_delete_and_fallback(self):
        self.assertTrue(self.call({'action':'prompt','profile':'general','text':'通用提示词'})['ok'])
        created=self.call({'action':'add_profile','name':'会议'})['data']
        ident=created['id']
        self.assertFalse(self.call({'action':'rename_profile','id':ident,'name':'通用'})['ok'])
        renamed=self.call({'action':'rename_profile','id':ident,'name':'会议记录'})
        self.assertTrue(renamed['ok'])
        self.assertEqual(next(x['label'] for x in renamed['data']['profiles'] if x['id']==ident),'会议记录')
        deleted=self.call({'action':'delete_profile','id':ident})
        self.assertTrue(deleted['ok'])
        self.assertEqual(deleted['data']['id'],'general')
        self.assertNotIn(ident,json.loads((self.base/'prompts.json').read_text()))
        self.assertFalse(self.call({'action':'profile','value':ident})['ok'])
        self.assertTrue(self.call({'action':'delete_profile','id':'general'})['ok'])
        self.assertEqual((self.base/'active-profile').read_text().strip(),'code')
        self.assertTrue(self.call({'action':'delete_profile','id':'chat'})['ok'])
        self.assertFalse(self.call({'action':'delete_profile','id':'code'})['ok'])
        env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.home/'.config'))
        self.assertNotEqual(subprocess.run([str(SCRIPT.parent/'voxtype-profile'),'set','general'],env=env).returncode,0)

    def test_provider_delete_and_fallback(self):
        (self.base/'deepseek-api-key').write_text('legacy')
        result=self.call({'action':'provider','name':'新供应商','url':'https://example.com/chat/completions','model':'m','key':'secret'})
        ident=result['data']['active']
        deleted=self.call({'action':'delete_provider','id':ident})
        self.assertTrue(deleted['ok'])
        self.assertEqual(deleted['data']['active'],'legacy')
        self.assertFalse((self.base/('provider-key-'+ident)).exists())
        self.assertFalse(self.call({'action':'delete_provider','id':'legacy'})['ok'])
        self.assertEqual((self.base/'deepseek-api-key').read_text(),'legacy')

    def test_multiple_providers_and_legacy_compatibility(self):
        (self.base/'provider.json').write_text(json.dumps({'name':'Old','url':'https://old.example','model':'old'}))
        (self.base/'deepseek-api-key').write_text('old-secret')
        self.assertFalse(self.call({'action':'provider','name':'X','url':'http://example.com','model':'m','key':'k'})['ok'])
        self.assertFalse(self.call({'action':'provider','name':'X','url':'https://example.com','model':'m','key':''})['ok'])
        result = self.call({'action':'provider','name':'X','url':'https://example.com','model':'m','key':'secret'})
        self.assertTrue(result['ok'])
        ident = result['data']['active']
        self.assertEqual(len(result['data']['items']), 2)
        self.assertNotIn('secret', json.dumps(result))
        self.assertEqual((self.base/('provider-key-'+ident)).stat().st_mode & 0o777, 0o600)
        self.assertTrue(self.call({'action':'select_provider','id':'legacy'})['ok'])
        self.assertEqual(json.loads((self.base/'providers.json').read_text())['active'], 'legacy')
        self.assertEqual((self.base/'deepseek-api-key').read_text(), 'old-secret')
        self.assertFalse(self.call({'action':'select_provider','id':'missing'})['ok'])
        self.assertFalse(self.call({'action':'provider','id':ident,'name':'X','url':'https://changed.example','model':'m','key':''})['ok'])
        self.assertTrue(self.call({'action':'provider','id':ident,'name':'X','url':'https://example.com','model':'new','key':''})['ok'])

    def test_delete_history_only_selected_entry(self):
        with sqlite3.connect(self.base/'history.sqlite3') as db:
            db.execute('CREATE TABLE history (id INTEGER PRIMARY KEY, created TEXT, profile TEXT, input TEXT, output TEXT, success INTEGER)')
            db.executemany('INSERT INTO history VALUES (?,?,?,?,?,?)', [(1,'2026-01-01','code','a','b',1),(2,'2026-01-02','chat','c','d',1)])
        self.assertTrue(self.call({'action':'delete_history','id':1})['ok'])
        self.assertFalse(self.call({'action':'delete_history','id':1})['ok'])
        self.assertFalse(self.call({'action':'delete_history','id':True})['ok'])
        with sqlite3.connect(self.base/'history.sqlite3') as db:
            self.assertEqual(db.execute('SELECT id FROM history').fetchall(),[(2,)])

    def test_statistics_time_ranges_and_totals(self):
        backend = runpy.run_path(str(SCRIPT))
        stats = backend['statistics']
        stats.__globals__['base'] = self.base
        with sqlite3.connect(self.base/'history.sqlite3') as db:
            db.execute('CREATE TABLE history (created TEXT, profile TEXT, output TEXT, success INTEGER)')
            db.executemany('INSERT INTO history VALUES (?,?,?,?)', [
                ('2026-10-29T10:00:00+08:00','general','你好',1),
                ('2026-10-23T12:00:00+08:00','code','abc',0),
                ('2026-09-30T12:00:00+08:00','chat','older',1),
                ('2026-01-01T12:00:00+08:00','unknown','x',1),
                ('2026-10-29T14:00:00+08:00','custom_abc','x',1),
                ('invalid','general','ignored',1),
            ])
        today = datetime.date(2026,10,29)
        week = stats(7,today)
        self.assertEqual((week['total'],week['success'],week['characters']), (3,2,6))
        self.assertEqual(week['profiles'], {'general':1,'code':1,'custom_abc':1})
        self.assertEqual(stats(30,today)['total'], 4)
        self.assertEqual(stats(0,today)['profiles']['unknown'], 1)
        quarter=stats(90,today)
        self.assertGreater(len(quarter['trend']),12)
        self.assertEqual(sum(x['count'] for x in quarter['trend']),quarter['total'])
        with self.assertRaises(ValueError): stats(5,today)

    def test_current_speech_model_matches_engine_model_name(self):
        backend=runpy.run_path(str(SCRIPT))
        class Result:
            def __init__(self, value): self.stdout=json.dumps({'value':value})
        model_data={'engines':{'moonshine':{'models':[{'name':'base','download_arg':'moonshine-base','installed':True}]}}}
        with patch('subprocess.run', side_effect=[Result('moonshine'),Result('base')]):
            self.assertEqual(backend['current_speech_model'](model_data),'moonshine-base')

    def test_translation_catalogs_cover_ui_and_placeholders(self):
        plugin=SCRIPT.parent.parent/'plugin'
        english=json.loads((plugin/'i18n/en.json').read_text())
        chinese=json.loads((plugin/'i18n/zh-CN.json').read_text())
        self.assertEqual(set(english),set(chinese))
        for qml in (plugin/'Panel.qml',plugin/'BarWidget.qml'):
            for key in re.findall(r'strings\.tn?\("([^"\n]+)"',qml.read_text()):
                self.assertIn(key,english)
        for key in english:
            en=english[key] if isinstance(english[key],str) else english[key]['other']
            zh=chinese[key] if isinstance(chinese[key],str) else chinese[key]['other']
            self.assertEqual(set(re.findall(r'%[1-9]',en)),set(re.findall(r'%[1-9]',zh)),key)

    def test_fetch_models_and_credentials(self):
        backend = runpy.run_path(str(SCRIPT))
        fetch = backend['fetch_models']
        class Response(io.BytesIO):
            def __enter__(self): return self
            def __exit__(self, *args): self.close()
        class Opener:
            def __init__(self, payload): self.payload=payload; self.requests=[]
            def open(self, req, timeout):
                self.requests.append(req)
                return Response(json.dumps(self.payload).encode())
        opener = Opener({'data':[{'id':'z'}, {'id':'a'}, {'id':'a'}]})
        with patch('urllib.request.build_opener', return_value=opener):
            self.assertEqual(fetch('https://api.example/v1/chat/completions','secret'), ['a','z'])
        self.assertEqual(opener.requests[0].full_url, 'https://api.example/v1/models')
        self.assertEqual(opener.requests[0].get_header('Authorization'), 'Bearer secret')
        aliyun = Opener({'output':{'models':[{'model':'qwen-plus'}],'total':1}})
        with patch('urllib.request.build_opener', return_value=aliyun):
            self.assertEqual(fetch('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions','secret'), ['qwen-plus'])
        self.assertIn('/api/v1/models?', aliyun.requests[0].full_url)
        with self.assertRaises(ValueError): fetch('http://example.com/chat/completions','secret')
        result = self.call({'action':'provider_models','id':'legacy','url':'https://other.example/chat/completions','key':''})
        self.assertFalse(result['ok'])

if __name__ == '__main__': unittest.main()
