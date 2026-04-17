import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../core/auth/auth.service';
import { PremiumService } from '../../features/premium/services/premium.service';

@Component({
  selector: 'wtm-sidebar',
  standalone: true,
  imports: [
    RouterLink,
    RouterLinkActive,
    MatListModule,
    MatIconModule,
    MatButtonModule,
    MatChipsModule,
    TranslateModule,
  ],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SidebarComponent {
  protected auth = inject(AuthService);
  protected premium = inject(PremiumService);

  protected readonly userInitial = computed(() => {
    const u = this.auth.currentUser();
    return (u?.displayName || u?.email || '?')[0].toUpperCase();
  });

  protected readonly userName = computed(() =>
    this.auth.currentUser()?.displayName || this.auth.currentUser()?.email || ''
  );

  protected logout(): void {
    this.auth.signOut();
  }

  protected login(): void {
    this.auth.signInWithGoogle();
  }
}
