import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { TimeInputComponent } from './time-input';

// Der Clear-Button (X) im Zeitfeld folgt dem `disabled`-Input (#426): während einer Schreibaktion im Dashboard darf
// „Endzeit löschen“ nicht bedienbar sein.
describe('TimeInputComponent Clear-Button (#426)', () => {
  let fixture: ComponentFixture<TimeInputComponent>;

  const clearButton = (): HTMLButtonElement => fixture.nativeElement.querySelector('button[matSuffix]') as HTMLButtonElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideTranslateService()] });
    fixture = TestBed.createComponent(TimeInputComponent);
    fixture.componentRef.setInput('label', 'Ende');
    fixture.componentRef.setInput('showClear', true);
    fixture.componentRef.setInput('value', new Date(2026, 9, 5, 12, 0));
    fixture.detectChanges();
  });

  it('ist aktiv und löst cleared aus, solange das Feld nicht deaktiviert ist', () => {
    const cleared = vi.fn();
    fixture.componentInstance.cleared.subscribe(cleared);
    expect(clearButton().disabled).toBe(false);
    clearButton().click();
    expect(cleared).toHaveBeenCalledTimes(1);
  });

  it('ist deaktiviert und löst nichts aus, wenn das Feld deaktiviert ist', () => {
    fixture.componentRef.setInput('disabled', true);
    fixture.detectChanges();
    const cleared = vi.fn();
    fixture.componentInstance.cleared.subscribe(cleared);
    expect(clearButton().disabled).toBe(true);
    clearButton().click();
    expect(cleared).not.toHaveBeenCalled();
  });

  it('wird nach dem Aufheben der Deaktivierung wieder aktiv', () => {
    fixture.componentRef.setInput('disabled', true);
    fixture.detectChanges();
    fixture.componentRef.setInput('disabled', false);
    fixture.detectChanges();
    expect(clearButton().disabled).toBe(false);
  });
});
