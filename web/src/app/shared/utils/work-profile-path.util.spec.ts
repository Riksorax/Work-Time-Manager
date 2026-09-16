import { profileScopedPath } from './work-profile-path.util';

describe('work-profile-path.util', () => {
  describe('profileScopedPath', () => {
    it('liefert den bestehenden Pfad ohne profileId', () => {
      expect(profileScopedPath('uid1', 'work_entries', undefined))
        .toEqual('users/uid1/work_entries');
    });

    it('liefert den bestehenden Pfad für profileId null', () => {
      expect(profileScopedPath('uid1', 'work_entries', null))
        .toEqual('users/uid1/work_entries');
    });

    it('liefert den bestehenden Pfad für "default"', () => {
      expect(profileScopedPath('uid1', 'settings', 'default'))
        .toEqual('users/uid1/settings');
    });

    it('liefert die Profil-Subcollection für ein zusätzliches Profil', () => {
      expect(profileScopedPath('uid1', 'overtime', 'p1'))
        .toEqual('users/uid1/profiles/p1/overtime');
    });
  });
});
