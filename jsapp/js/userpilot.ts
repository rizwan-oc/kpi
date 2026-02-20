/**
 * UserPilot integration utility
 * Handles initialization and user identification for UserPilot SDK (npm package)
 */
import {Userpilot} from 'userpilot';
import {AccountResponse} from 'js/dataInterface';

class UserPilotService {
  private readonly userPilotSdkToken: string | null = null;

  constructor() {
    const tokenEl = document.head.querySelector('meta[name=user_pilot_sdk_token]');
    if (tokenEl && tokenEl instanceof HTMLMetaElement) {
      this.userPilotSdkToken = tokenEl.content;
      this.initialize();
    }
  }

  /**
   * Initialize UserPilot with the token
   */
  private initialize(): void {
    if (!this.userPilotSdkToken) {
      console.warn('[Userpilot] No SDK token found, Userpilot not initialized');
      return;
    }
    try {
      Userpilot.initialize(this.userPilotSdkToken);
    } catch (error) {
      console.error('[Userpilot] Error during initialization:', error);
    }
  }

  /**
   * Identify user to UserPilot
   * Should be called after user login
   */
  identify(accountResp: AccountResponse): void {
    if (!this.userPilotSdkToken) {
      return;
    }
    const userUuid = accountResp.user_uuid;
    if (!userUuid) {
      console.warn('[Userpilot] User UUID is not present. Skipping Identification');
      return;
    }
    const userProperties = {
      company: {
        id: accountResp.subdomain,
        name: accountResp.customer_name,
      }
    };
    try {
      Userpilot.identify(userUuid, userProperties);
    } catch (error) {
      console.warn('UserPilot identification failed:', error);
    }
  }

  /**
   * Reload UserPilot content
   */
  reload(url: string): void {
    if (!this.userPilotSdkToken) {
      return;
    }
    try {
      Userpilot.reload(url);
    } catch (error) {
      console.warn('UserPilot reload failed:', error);
    }
  }
}

// Export singleton instance
export default new UserPilotService();
