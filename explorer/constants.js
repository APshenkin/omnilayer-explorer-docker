/*
 * AppConstants
 * Each action has a corresponding type, which the reducer knows and picks up on.
 * To avoid weird typos between the reducer and the actions, we save them as
 * constants here. We prefix them with 'yourproject/YourComponent' so we avoid
 * reducers accidentally picking up actions they shouldn't.
 *
 * Follow this format:
 * export const YOUR_ACTION_CONSTANT = 'yourproject/YourContainer/YOUR_ACTION_CONSTANT';
 */

export let API_URL_BASE = 'https://omniapi:80/v1';
export const DEFAULT_LOCALE = 'en';
export const DEFAULT_NOT_NUMBER = '---';
export const ECOSYSTEM_PROD = 1;
export const ECOSYSTEM_TEST = 2;
export const ECOSYSTEM_PROD_NAME = 'Production';
export const ECOSYSTEM_TEST_NAME = 'Test';

const setApiUrl = () => {
  const hostName = window.location.hostname;

  if (/localhost/i.test(hostName)) {
    API_URL_BASE = 'https://localhost:4005/v1';
  } else {
    if (hostName.indexOf('mydomain.com') > -1) {
      API_URL_BASE = 'https://omni-api.mydomain.com/v1'
    } else {
      API_URL_BASE = 'https://omni-api.qa.mydomain.com/v1'
    }
  }
};

setApiUrl();
