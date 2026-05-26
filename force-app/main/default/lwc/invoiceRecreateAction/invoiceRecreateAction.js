import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import recreateInvoice from '@salesforce/apex/InvoiceActionController.recreateInvoice';

export default class InvoiceRecreateAction extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;

        try {
            const recreatedId = await recreateInvoice({ invoiceId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '成功',
                    message: '請求を再作成しました。',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recreatedId,
                    actionName: 'view'
                }
            });
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
        return '請求再作成に失敗しました。';
    }
}