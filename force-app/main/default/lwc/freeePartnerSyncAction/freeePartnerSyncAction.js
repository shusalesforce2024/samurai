import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import syncPartner from '@salesforce/apex/FreeePartnerController.syncPartner';

export default class FreeePartnerSyncAction extends LightningElement {
    @api recordId;
    isLoading = false;

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;

        try {
            const result = await syncPartner({ accountId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '同期完了',
                    message: result.message,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '同期失敗',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'freee取引先同期に失敗しました。';
    }
}