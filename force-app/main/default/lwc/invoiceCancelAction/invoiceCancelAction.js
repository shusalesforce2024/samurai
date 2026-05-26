import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import cancelInvoice from '@salesforce/apex/InvoiceActionController.cancelInvoice';

export default class InvoiceCancelAction extends LightningElement {
    @api recordId;
    isLoading = false;

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;

        try {
            const message = await cancelInvoice({ invoiceId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '成功',
                    message: message,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'エラー',
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
        return '請求取消に失敗しました。';
    }
}