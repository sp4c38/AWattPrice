import unittest

from box import Box
from pathlib import Path

from awattprice import configurator
from awattprice import defaults
from awattprice_notifications import cronitor
from awattprice_notifications.worker import service


def cronitor_config():
    return Box(
        {
            "cronitor": {
                "api_key": "api-key",
                "monitor_key": "notifications-worker",
                "environment": "production",
            },
            "paths": {"data_dir": Path("/tmp")},
        }
    )


class CronitorConfigTests(unittest.TestCase):
    def test_default_config_requires_cronitor_credentials(self):
        config = configurator.Config(defaults.DEFAULT_CONFIG)

        self.assertFalse(cronitor.is_enabled(config))
        self.assertEqual(config.cronitor.environment, "production")

    def test_build_params_contains_job_state_and_metrics(self):
        params = cronitor.build_params(
            cronitor_config(),
            "complete",
            "series-123",
            message="finished",
            duration=1.23456,
            count=3,
            error_count=1,
            status_code=0,
        )

        self.assertIn(("state", "complete"), params)
        self.assertIn(("series", "series-123"), params)
        self.assertIn(("env", "production"), params)
        self.assertIn(("message", "finished"), params)
        self.assertIn(("metric", "duration:1.235"), params)
        self.assertIn(("metric", "count:3"), params)
        self.assertIn(("metric", "error_count:1"), params)
        self.assertIn(("status_code", "0"), params)

    def test_missing_credentials_raise(self):
        config = cronitor_config()
        config.cronitor.monitor_key = None

        self.assertFalse(cronitor.is_enabled(config))
        with self.assertRaises(RuntimeError):
            cronitor.require_configured(config)


class CronitorSendTests(unittest.IsolatedAsyncioTestCase):

    async def test_enabled_cronitor_sends_request(self):
        calls = []
        original_async_client = cronitor.httpx.AsyncClient

        class FakeClient:
            def __init__(self, timeout):
                self.timeout = timeout

            async def __aenter__(self):
                return self

            async def __aexit__(self, _exc_type, _exc, _traceback):
                return False

            async def get(self, url, params):
                calls.append((url, params, self.timeout))

        try:
            cronitor.httpx.AsyncClient = FakeClient

            sent = await cronitor.send_event(cronitor_config(), "run", "series-123", message="started")
        finally:
            cronitor.httpx.AsyncClient = original_async_client

        self.assertTrue(sent)
        self.assertEqual(calls[0][0], "https://cronitor.link/p/api-key/notifications-worker")
        self.assertIn(("state", "run"), calls[0][1])
        self.assertIn(("message", "started"), calls[0][1])


class NotificationWorkerMonitoringTests(unittest.IsolatedAsyncioTestCase):
    async def test_main_exits_when_cronitor_is_missing(self):
        original_get_config = service.configurator.get_config
        original_configure_loguru = service.configurator.configure_loguru

        config = cronitor_config()
        config.cronitor.api_key = None

        try:
            service.configurator.get_config = lambda: config
            service.configurator.configure_loguru = lambda _service_name, _config: None

            with self.assertRaises(RuntimeError):
                await service.main()
        finally:
            service.configurator.get_config = original_get_config
            service.configurator.configure_loguru = original_configure_loguru

    async def test_main_reports_complete_for_noop_cycle(self):
        events = []
        original_get_config = service.configurator.get_config
        original_configure_loguru = service.configurator.configure_loguru
        original_store = service.notification_profiles.NotificationProfileStore
        original_send_event = service.cronitor.send_event

        async def fake_send_event(_config, state, _series, **kwargs):
            events.append((state, kwargs))
            return True

        class FakeStore:
            def __init__(self, _path):
                pass

            def list_profiles(self):
                return []

        try:
            service.configurator.get_config = lambda: cronitor_config()
            service.configurator.configure_loguru = lambda _service_name, _config: None
            service.notification_profiles.NotificationProfileStore = FakeStore
            service.cronitor.send_event = fake_send_event

            await service.main()
        finally:
            service.configurator.get_config = original_get_config
            service.configurator.configure_loguru = original_configure_loguru
            service.notification_profiles.NotificationProfileStore = original_store
            service.cronitor.send_event = original_send_event

        self.assertEqual([event[0] for event in events], ["run", "complete"])
        self.assertIn("no_active_subscriptions", events[-1][1]["message"])

    async def test_main_reports_fail_for_worker_exception(self):
        events = []
        original_get_config = service.configurator.get_config
        original_configure_loguru = service.configurator.configure_loguru
        original_store = service.notification_profiles.NotificationProfileStore
        original_run_worker_cycle = service.run_worker_cycle
        original_send_event = service.cronitor.send_event

        async def fake_send_event(_config, state, _series, **kwargs):
            events.append((state, kwargs))
            return True

        class FakeStore:
            def __init__(self, _path):
                pass

        async def failing_run_worker_cycle(_config, _store):
            raise RuntimeError("boom")

        try:
            service.configurator.get_config = lambda: cronitor_config()
            service.configurator.configure_loguru = lambda _service_name, _config: None
            service.notification_profiles.NotificationProfileStore = FakeStore
            service.run_worker_cycle = failing_run_worker_cycle
            service.cronitor.send_event = fake_send_event

            with self.assertRaises(RuntimeError):
                await service.main()
        finally:
            service.configurator.get_config = original_get_config
            service.configurator.configure_loguru = original_configure_loguru
            service.notification_profiles.NotificationProfileStore = original_store
            service.run_worker_cycle = original_run_worker_cycle
            service.cronitor.send_event = original_send_event

        self.assertEqual([event[0] for event in events], ["run", "fail"])
        self.assertEqual(events[-1][1]["error_count"], 1)
