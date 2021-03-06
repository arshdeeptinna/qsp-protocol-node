####################################################################################################
#                                                                                                  #
# (c) 2018, 2019 Quantstamp, Inc. This content and its use are governed by the license terms at    #
# <https://s3.amazonaws.com/qsp-protocol-license/V2_LICENSE.txt>                                   #
#                                                                                                  #
####################################################################################################

from time import sleep
from unittest import mock

from audit import UpdateMinPriceThread
from helpers.qsp_test import QSPTest
from helpers.resource import fetch_config
from timeout_decorator import timeout
from utils.eth.tx import TransactionNotConfirmedException
from utils.eth.tx import DeduplicationException
from web3.utils.threads import Timeout


class TestUpdateMinPriceThread(QSPTest):
    __SLEEP_INTERVAL = 1

    def __evt_wait_loop(self, current_filter):
        events = current_filter.get_new_entries()
        while not bool(events):
            sleep(TestUpdateMinPriceThread.__SLEEP_INTERVAL)
            events = current_filter.get_new_entries()
        return events

    def test_init(self):
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        self.assertEqual(config, thread.config)

    def test_update_min_price_success(self):
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        return_value="hash"):
            thread.update_min_price()

    def test_update_min_price_exceptions(self):
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        side_effect=Exception):
            try:
                thread.update_min_price()
                self.fail("Exception was not propagated")
            except Exception:
                # expected
                pass

        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        side_effect=TransactionNotConfirmedException):
            try:
                thread.update_min_price()
                self.fail("Exception was not propagated")
            except TransactionNotConfirmedException:
                # expected
                pass

        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        side_effect=Timeout):
            try:
                thread.update_min_price()
                self.fail("Exception was not propagated")
            except Timeout:
                # expected
                pass

        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        side_effect=DeduplicationException):
            try:
                thread.update_min_price()
                self.fail("Exception was not propagated")
            except DeduplicationException:
                # expected
                pass

    def test_check_and_update_min_price(self):
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        return_value="hash"), \
             mock.patch('audit.threads.update_min_price_thread.mk_read_only_call',
                        return_value=config.min_price_in_qsp + 5):
            thread.check_and_update_min_price()

    def test_stop(self):
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        thread.stop()
        self.assertFalse(thread.exec)

    @timeout(30, timeout_exception=StopIteration)
    def test_change_min_price(self):
        """
        Tests that the node updates the min_price on the blockchain if the config value changes
        """

        config = fetch_config(inject_contract=True)
        set_audit_price_filter = config.audit_contract.events.setAuditNodePrice_called.createFilter(
            fromBlock=max(0, config.event_pool_manager.get_latest_block_number())
        )

        # this make a one-off call
        config._Config__min_price_in_qsp = 1
        thread = UpdateMinPriceThread(config)
        thread.update_min_price()

        success = False
        while not success:
            events = self.__evt_wait_loop(set_audit_price_filter)
            for event in events:
                self.assertEqual(event['event'], 'setAuditNodePrice_called')
                if event['args']['price'] == 10 ** 18:
                    success = True
                    break
            if not success:
                sleep(TestUpdateMinPriceThread.__SLEEP_INTERVAL)

    @timeout(15, timeout_exception=StopIteration)
    def test_start_stop(self):
        # start the thread, signal stop and exit. use mock not to make work
        config = fetch_config(inject_contract=True)
        thread = UpdateMinPriceThread(config)
        with mock.patch('audit.threads.update_min_price_thread.send_signed_transaction',
                        return_value="hash"):
            thread.start()
            while not thread.exec:
                sleep(0.1)
            thread.stop()
            self.assertFalse(thread.exec)
